defmodule Huddlz.Communities.Huddl.RecurrenceHelper do
  @moduledoc """
  Generating and reconciling a recurring huddl series.

  Two entry points, and only the first ever creates a huddl:

    * `fill_window/2` — creates the occurrences missing from the series'
      rolling window. Called by `MaintainRecurringSeries`, on create and once a
      day thereafter.
    * `reconcile_future_instances/4` — used by "edit all". Updates the existing
      future occurrences *in place*, preserving every RSVP and waitlist spot
      and notifying their subscribers, and removes occurrences an edit dropped.
      It never creates: an edit changes the series, and filling the window is
      the scheduled job's business.
  """

  alias Huddlz.Communities
  alias Huddlz.Communities.Huddl
  alias Huddlz.Communities.Huddl.CoverCopy
  alias Huddlz.Communities.Huddl.SeriesWindow

  # Fields copied from the source huddl onto every generated/reconciled instance.
  @copied_attrs [
    :event_type,
    :title,
    :description,
    :group_location_id,
    :virtual_link,
    :is_private,
    :thumbnail_url,
    :max_attendees
  ]

  @doc """
  Creates the occurrences missing from the series' rolling window.

  The horizon is a count of **upcoming occurrences**, not of grid slots: it is
  `SeriesWindow.horizon/0` minus however many occurrences the series already
  has after `cutoff` (which defaults to now), in any lifecycle state. Without
  this cap, an "edit all" that moves the template's anchor mid-series leaves
  the still-upcoming occurrences *before* the new anchor outside the grid
  `SeriesWindow.next_occurrences/3` searches, so they contribute nothing to
  the count and every sweep pads on a fresh set of grid slots on top of them.

  A date already occupied by an occurrence in **any** lifecycle state is left
  alone. That is what keeps a cancelled week cancelled rather than helpfully
  resurrecting it, repairs a gap left by a partial failure, and makes a retried
  or overlapping run create nothing twice.

  Returns `{:error, :no_source}` when the series has no huddl left to copy
  details from. That is not a failure — there is simply nothing to generate.
  """
  def fill_window(template, cutoff \\ nil) do
    cutoff = cutoff || DateTime.utc_now()

    with {:ok, source} <- series_source(template),
         {:ok, occurrences} <- SeriesWindow.next_occurrences(template, cutoff) do
      existing = series_occurrences(template, cutoff)
      occupied = occupied_dates(template, existing)
      capacity = max(SeriesWindow.horizon() - length(existing), 0)

      occurrences
      |> Enum.reject(fn {starts_at, _ends_at} ->
        MapSet.member?(occupied, local_date(starts_at, template.time_zone))
      end)
      |> Enum.take(capacity)
      |> Enum.each(fn {starts_at, ends_at} ->
        create_instance!(source, template, starts_at, ends_at)
      end)

      :ok
    end
  end

  defp local_date(datetime, time_zone) do
    datetime |> DateTime.shift_zone!(time_zone) |> DateTime.to_date()
  end

  defp occupied_dates(template, existing) do
    MapSet.new(existing, &local_date(&1.starts_at, template.time_zone))
  end

  @doc """
  The single answer to "which huddl does this series copy from": normally the
  template's designated source; when that huddl has been hard-deleted the
  pointer is nilified, so fall back to the series' latest occurrence. Used
  both to generate new occurrences (`fill_window/2`) and, by
  `MaintainRecurringSeries`, to find the series' current group for the
  archived-group guard — the two must never resolve to different huddlz.

  Returns `{:error, :no_source}` when the series has no huddl left to copy
  from.
  """
  def series_source(%{source_huddl_id: nil} = template), do: latest_occurrence(template)

  def series_source(template) do
    Huddl
    |> Ash.Query.for_read(:get_for_recurrence, %{id: template.source_huddl_id})
    |> Ash.read_one!(authorize?: false)
    |> case do
      %Huddl{} = source -> {:ok, source}
      nil -> latest_occurrence(template)
    end
  end

  defp latest_occurrence(template) do
    Huddl
    |> Ash.Query.for_read(:siblings_in_series, %{
      huddl_template_id: template.id,
      starting_after: ~U[1970-01-01 00:00:00Z]
    })
    |> Ash.Query.sort(starts_at: :desc)
    |> Ash.Query.limit(1)
    |> Ash.read_one!(authorize?: false)
    |> case do
      %Huddl{} = source -> {:ok, source}
      nil -> {:error, :no_source}
    end
  end

  defp series_occurrences(template, starting_after) do
    Huddl
    |> Ash.Query.for_read(:siblings_in_series, %{
      huddl_template_id: template.id,
      starting_after: starting_after
    })
    |> Ash.read!(authorize?: false)
  end

  @doc """
  Reconciles the series' future instances to match `source` and `template`,
  preserving subscribers:

    * existing future instances are **updated in place** to the source's fields
      and recomputed times (RSVPs untouched; the series change sends one summary
      per affected person)
    * dates the series no longer reaches are **removed**: published ones are
      cancelled, so their subscribers get the notice and the RSVP history
      stands, and unpublished ones are destroyed
    * nothing is created — extending a series materializes on the next
      scheduled sweep, not on the edit

  `actor` is the editor; it is threaded through so they are excluded from the
  update emails for instances they're attending.
  """
  def reconcile_future_instances(source, template, actor, context \\ %{}) do
    opts = [actor: actor, authorize?: false, context: context]

    existing =
      source
      |> future_instances()
      |> Enum.filter(&(&1.lifecycle_state in [:draft, :published]))
      |> Enum.sort_by(& &1.starts_at, DateTime)

    with {:ok, desired} <-
           SeriesWindow.next_occurrences(template, source.starts_at, length(existing)) do
      reconcile_desired_instances(source, opts, existing, desired)
    end
  end

  @doc false
  # Later instances in the series, read through the dedicated visibility-free
  # action so a private series is reached in full regardless of actor.
  def future_instances(source) do
    Huddl
    |> Ash.Query.for_read(:siblings_in_series, %{
      huddl_template_id: source.huddl_template_id,
      starting_after: source.starts_at
    })
    |> Ash.read!(authorize?: false)
  end

  defp reconcile_desired_instances(source, opts, existing, desired) do
    # Asking for no more dates than already exist makes the creation branch of
    # match_occurrences/2 unreachable, which is the point: an edit re-dates and
    # removes, never creates. Filling the window is the scheduled job's work,
    # so the empty list here is an assertion, not a discard.
    {retained, [], obsolete} = match_occurrences(existing, desired)

    Enum.each(retained, fn {instance, {starts_at, ends_at}} ->
      update_instance!(instance, source, starts_at, ends_at, opts)
    end)

    Enum.each(obsolete, &remove_instance!(&1, opts))

    :ok
  end

  defp match_occurrences(existing, desired) do
    # Preserve exact calendar-date matches first so repairing a missing
    # occurrence never shifts a later RSVP onto the gap.
    existing_by_date = Map.new(existing, &{DateTime.to_date(&1.starts_at), &1})

    {exact_matches, unmatched_desired, remaining_by_date} =
      Enum.reduce(desired, {[], [], existing_by_date}, fn desired_occurrence,
                                                          {matches, unmatched, remaining} ->
        {starts_at, _ends_at} = desired_occurrence

        case Map.pop(remaining, DateTime.to_date(starts_at)) do
          {nil, remaining} ->
            {matches, [desired_occurrence | unmatched], remaining}

          {instance, remaining} ->
            {[{instance, desired_occurrence} | matches], unmatched, remaining}
        end
      end)

    unmatched_desired = Enum.reverse(unmatched_desired)

    unmatched_existing =
      remaining_by_date |> Map.values() |> Enum.sort_by(& &1.starts_at, DateTime)

    # Pair anything left in chronological order. This preserves row identity
    # when an edit shifts the whole schedule to dates with no exact matches.
    {paired_existing, obsolete_existing} =
      Enum.split(unmatched_existing, length(unmatched_desired))

    {paired_desired, new_desired} =
      Enum.split(unmatched_desired, length(paired_existing))

    retained = Enum.reverse(exact_matches) ++ Enum.zip(paired_existing, paired_desired)

    {retained, new_desired, obsolete_existing}
  end

  defp create_instance!(source, template, starts_at, ends_at, opts \\ []) do
    context = Keyword.get(opts, :context, %{})
    metadata = Map.put(context[:paper_trail_metadata] || %{}, :automatic?, true)

    instance =
      Huddl
      |> Ash.Changeset.new()
      |> Ash.Changeset.for_create(
        :create,
        instance_attrs(source, starts_at, ends_at, template),
        opts
      )
      |> Ash.Changeset.set_context(%{paper_trail_metadata: metadata})
      # Preserve series authorship after SetCreatorToActor runs, while the
      # initiating editor remains the actor for audit attribution. This hook
      # is internal; public creation still derives its creator from the actor.
      |> Ash.Changeset.before_action(fn changeset ->
        Ash.Changeset.force_change_attribute(changeset, :creator_id, source.creator_id)
      end)
      |> Ash.create!(authorize?: false)

    copy_current_image!(source, instance, metadata, opts)
    instance
  end

  defp copy_current_image!(source, instance, metadata, opts) do
    context = Map.put(Keyword.get(opts, :context, %{}), :paper_trail_metadata, metadata)

    case CoverCopy.copy_current(source.id, instance.id, Keyword.put(opts, :context, context)) do
      :ok -> :ok
      {:error, %{__exception__: true} = error} -> raise error
      {:error, reason} -> raise "failed to copy recurring huddl image: #{inspect(reason)}"
    end
  end

  defp destroy_instance!(instance, opts) do
    instance.id
    |> Communities.list_huddl_cover_images(authorize?: false)
    |> then(fn
      {:ok, images} ->
        Enum.each(images, fn image ->
          image
          |> Ash.Changeset.for_destroy(:hard_delete, %{}, opts)
          |> Ash.destroy!(authorize?: false)
        end)

      {:error, error} ->
        raise error
    end)

    instance
    |> Ash.Changeset.for_destroy(:destroy, %{}, opts)
    |> Ash.destroy!(authorize?: false)
  end

  defp remove_instance!(%{lifecycle_state: :draft} = instance, opts) do
    destroy_instance!(instance, opts)
  end

  defp remove_instance!(%{lifecycle_state: :published} = instance, opts) do
    Communities.cancel_huddl!(instance, nil, opts)
  end

  defp remove_instance!(%{lifecycle_state: state}, _actor)
       when state in [:cancelled, :completed],
       do: :ok

  # Updates a kept instance in place via the :update action with
  # edit_type "instance", so the per-instance update notification emails this
  # occurrence's subscribers without re-triggering series reconciliation.
  defp update_instance!(instance, source, starts_at, ends_at, opts) do
    instance
    |> Ash.Changeset.new()
    |> Ash.Changeset.set_argument(:suppress_update_notification, true)
    |> Ash.Changeset.for_update(
      :update,
      instance_attrs(source, starts_at, ends_at) |> Map.put(:edit_type, "instance"),
      opts
    )
    |> Ash.update!(authorize?: false)
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
      |> Map.put(:lifecycle_state, generated_lifecycle_state(source))
    else
      base
    end
  end

  # A generated occurrence's lifecycle reflects the *series*, not whatever
  # state the source huddl happens to be in right now. The source drifts
  # through :completed (once its own date passes) and :cancelled (if that one
  # week is called off) while the series itself is still very much alive, and
  # the `:create` action only accepts :draft or :published — copying
  # :completed or :cancelled straight through would make every future
  # generation attempt raise. Draft is the one state that says "the series
  # itself isn't live yet"; anything else means new occurrences should be
  # published.
  defp generated_lifecycle_state(%{lifecycle_state: :draft}), do: :draft
  defp generated_lifecycle_state(_source), do: :published
end
