defmodule Huddlz.Communities.Huddl.RecurrenceHelper do
  @moduledoc """
  Shared logic for generating recurring huddlz from a template.
  """

  alias Huddlz.Communities.Huddl

  require Ash.Query

  @max_instances 104

  @doc """
  Replaces a series' future instances: deletes every later instance sharing the
  template, then regenerates them from `huddl`. Idempotent, so it is safe to run
  from a retried Oban job or a synchronous "edit all" without duplicating the
  series.
  """
  def regenerate_series(huddl, huddl_template) do
    delete_future_instances(huddl)
    generate_huddlz_from_template(huddl_template, huddl)
    :ok
  end

  # Clears later instances through the dedicated, visibility-free
  # :siblings_in_series read so a private series is cleared in full regardless
  # of who (or what) triggers the regeneration.
  defp delete_future_instances(huddl) do
    Huddl
    |> Ash.Query.for_read(:siblings_in_series, %{
      huddl_template_id: huddl.huddl_template_id,
      starting_after: huddl.starts_at
    })
    |> Ash.read!(authorize?: false)
    |> Enum.each(&Ash.destroy!(&1, authorize?: false))
  end

  @doc """
  Recursively generates future huddlz based on the template's frequency
  and repeat_until date. Each new huddl copies the source huddl's properties
  and advances the start/end times by the appropriate interval.

  Stops after `@max_instances` (#{@max_instances}) to prevent unbounded generation.
  """
  def generate_huddlz_from_template(huddl_template, huddl, count \\ 0)

  def generate_huddlz_from_template(_huddl_template, _huddl, count)
      when count >= @max_instances,
      do: :ok

  def generate_huddlz_from_template(huddl_template, huddl, count) do
    interval_days = frequency_days(huddl_template.frequency)
    starts_at = DateTime.add(huddl.starts_at, interval_days, :day)
    ends_at = DateTime.add(huddl.ends_at, interval_days, :day)
    start_at_date = DateTime.to_date(starts_at)

    if Date.before?(start_at_date, huddl_template.repeat_until) do
      new_huddl =
        Huddl
        |> Ash.Changeset.new()
        # Reuse the source huddl's already-resolved coordinates so each instance
        # skips geocoding (ApplyProvidedCoordinates short-circuits GeocodeChange).
        # These are private args, so they must be set before for_create; nil is
        # ignored, so virtual huddlz still work.
        |> Ash.Changeset.set_argument(:provided_latitude, huddl.latitude)
        |> Ash.Changeset.set_argument(:provided_longitude, huddl.longitude)
        |> Ash.Changeset.for_create(:create, %{
          starts_at: starts_at,
          ends_at: ends_at,
          event_type: huddl.event_type,
          title: huddl.title,
          description: huddl.description,
          physical_location: huddl.physical_location,
          is_private: huddl.is_private,
          thumbnail_url: huddl.thumbnail_url,
          group_id: huddl.group_id,
          huddl_template_id: huddl_template.id
        })
        # creator_id is not an accepted input — the :create action derives it
        # from the actor. This internal, actorless generation sets it directly
        # so each instance inherits the parent huddl's creator (SetCreatorToActor
        # leaves it untouched when no actor is present).
        |> Ash.Changeset.force_change_attribute(:creator_id, huddl.creator_id)
        |> Ash.create!(authorize?: false)

      generate_huddlz_from_template(huddl_template, new_huddl, count + 1)
    end
  end

  defp frequency_days(:weekly), do: 7
  defp frequency_days(:monthly), do: 30
end
