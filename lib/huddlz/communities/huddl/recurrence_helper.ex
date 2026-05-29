defmodule Huddlz.Communities.Huddl.RecurrenceHelper do
  @moduledoc """
  Shared logic for generating and reconciling a recurring huddl series.

  Two entry points:

    * `regenerate_series/2` — used by the create-path worker. Clears and rebuilds
      the future instances. Safe because freshly-created series have no
      subscribers to lose.
    * `reconcile_future_instances/3` — used by "edit all". Updates the existing
      future instances *in place* (preserving every RSVP/waitlist spot and
      notifying their subscribers), creates any newly-added dates, and only
      destroys dates that fall off the schedule.
  """

  alias Huddlz.Communities.Huddl

  require Ash.Query

  @max_instances 104

  # Fields copied from the source huddl onto every generated/reconciled instance.
  @copied_attrs [
    :event_type,
    :title,
    :description,
    :physical_location,
    :is_private,
    :thumbnail_url
  ]

  @doc """
  Clears every later instance in the series and regenerates them from `source`.
  Idempotent, so a retried create-path Oban job rebuilds rather than duplicates.
  Only appropriate when the instances have no subscribers (create path) — it
  cascade-deletes RSVPs. "Edit all" uses `reconcile_future_instances/3` instead.
  """
  def regenerate_series(source, template) do
    source |> future_instances() |> Enum.each(&Ash.destroy!(&1, authorize?: false))
    generate_huddlz_from_template(template, source)
    :ok
  end

  @doc """
  Reconciles the series' future instances to match `source` and `template`,
  preserving subscribers:

    * existing future instances are **updated in place** to the source's fields
      and recomputed times (RSVPs untouched; each meaningful change emails that
      instance's subscribers via the per-instance update notification)
    * dates added by extending the series are **created**
    * dates dropped by shortening the series / changing frequency are
      **destroyed** (a real cancellation — their subscribers get the cancel notice)

  `actor` is the editor; it is threaded through so they are excluded from the
  update emails for instances they're attending.
  """
  def reconcile_future_instances(source, template, actor) do
    desired = desired_occurrences(source, template)
    existing = source |> future_instances() |> Enum.sort_by(& &1.starts_at, DateTime)

    # Update the overlapping positions in place.
    desired
    |> Enum.zip(existing)
    |> Enum.each(fn {{starts_at, ends_at}, instance} ->
      update_instance!(instance, source, starts_at, ends_at, actor)
    end)

    # Create dates the series gained.
    desired
    |> Enum.drop(length(existing))
    |> Enum.each(fn {starts_at, ends_at} ->
      create_instance!(source, template, starts_at, ends_at)
    end)

    # Cancel dates the series lost.
    existing
    |> Enum.drop(length(desired))
    |> Enum.each(&Ash.destroy!(&1, actor: actor, authorize?: false))

    :ok
  end

  @doc """
  Recursively generates future huddlz based on the template's frequency and
  repeat_until date. Each new huddl copies the source huddl's properties and
  advances the start/end times by the appropriate interval.

  Stops after `@max_instances` (#{@max_instances}) to prevent unbounded generation.
  """
  def generate_huddlz_from_template(template, source, count \\ 0)

  def generate_huddlz_from_template(_template, _source, count) when count >= @max_instances,
    do: :ok

  def generate_huddlz_from_template(template, source, count) do
    interval_days = frequency_days(template.frequency)
    starts_at = DateTime.add(source.starts_at, interval_days, :day)
    ends_at = DateTime.add(source.ends_at, interval_days, :day)

    if Date.before?(DateTime.to_date(starts_at), template.repeat_until) do
      new_huddl = create_instance!(source, template, starts_at, ends_at)
      generate_huddlz_from_template(template, new_huddl, count + 1)
    else
      :ok
    end
  end

  # Later instances in the series, read through the dedicated visibility-free
  # action so a private series is reached in full regardless of actor.
  defp future_instances(source) do
    Huddl
    |> Ash.Query.for_read(:siblings_in_series, %{
      huddl_template_id: source.huddl_template_id,
      starting_after: source.starts_at
    })
    |> Ash.read!(authorize?: false)
  end

  # The start/end times the series should have, from the source forward, capped
  # at @max_instances. Times shift with the source, so editing the time moves
  # every future occurrence.
  defp desired_occurrences(source, template) do
    interval_days = frequency_days(template.frequency)
    duration = DateTime.diff(source.ends_at, source.starts_at, :second)

    1..@max_instances
    |> Enum.reduce_while([], fn k, acc ->
      starts_at = DateTime.add(source.starts_at, k * interval_days, :day)

      if Date.before?(DateTime.to_date(starts_at), template.repeat_until) do
        {:cont, [{starts_at, DateTime.add(starts_at, duration, :second)} | acc]}
      else
        {:halt, acc}
      end
    end)
    |> Enum.reverse()
  end

  defp create_instance!(source, template, starts_at, ends_at) do
    Huddl
    |> Ash.Changeset.new()
    # Reuse the source's already-resolved coordinates so the instance skips
    # geocoding (ApplyProvidedCoordinates short-circuits GeocodeChange). Private
    # args, so set before for_create; nil is ignored, so virtual huddlz work.
    |> Ash.Changeset.set_argument(:provided_latitude, source.latitude)
    |> Ash.Changeset.set_argument(:provided_longitude, source.longitude)
    |> Ash.Changeset.for_create(:create, instance_attrs(source, starts_at, ends_at, template))
    # creator_id is not an accepted input — the :create action derives it from
    # the actor. This actorless generation sets it directly so each instance
    # inherits the source's creator (SetCreatorToActor no-ops without an actor).
    |> Ash.Changeset.force_change_attribute(:creator_id, source.creator_id)
    |> Ash.create!(authorize?: false)
  end

  # Updates a kept instance in place via the :update action with
  # edit_type "instance", so the per-instance update notification emails this
  # occurrence's subscribers without re-triggering series reconciliation.
  defp update_instance!(instance, source, starts_at, ends_at, actor) do
    instance
    |> Ash.Changeset.new()
    |> Ash.Changeset.set_argument(:provided_latitude, source.latitude)
    |> Ash.Changeset.set_argument(:provided_longitude, source.longitude)
    |> Ash.Changeset.for_update(
      :update,
      instance_attrs(source, starts_at, ends_at) |> Map.put(:edit_type, "instance")
    )
    |> Ash.update!(actor: actor, authorize?: false)
  end

  defp instance_attrs(source, starts_at, ends_at, template \\ nil) do
    base =
      @copied_attrs
      |> Map.new(fn attr -> {attr, Map.fetch!(source, attr)} end)
      |> Map.merge(%{starts_at: starts_at, ends_at: ends_at})

    if template do
      base
      |> Map.put(:group_id, source.group_id)
      |> Map.put(:huddl_template_id, template.id)
    else
      base
    end
  end

  defp frequency_days(:weekly), do: 7
  defp frequency_days(:monthly), do: 30
end
