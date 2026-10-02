defmodule Huddlz.Communities.Huddl.Changes.EditRecurringHuddlz do
  @moduledoc """
  Propagates an "edit all" to the rest of a recurring series.

  Updates every later instance **in place** so subscribers keep their RSVPs and
  are notified with one useful series summary per affected person (see
  `RecurrenceHelper.reconcile_future_instances/3`); it never
  deletes-and-recreates occupied occurrences.
  """
  use Ash.Resource.Change

  alias Huddlz.Communities.Huddl.Changes.NotifyMeaningfulUpdate
  alias Huddlz.Communities.Huddl.Changes.RecipientHelpers
  alias Huddlz.Communities.Huddl.Changes.SeriesRsvpTarget
  alias Huddlz.Communities.Huddl.RecurrenceHelper
  alias Huddlz.Communities.HuddlTemplate

  def change(changeset, _opts, context) do
    actor = context.actor
    changed_fields = NotifyMeaningfulUpdate.changed_fields(changeset)

    Ash.Changeset.after_action(changeset, fn _changeset, huddl ->
      if Ash.Changeset.get_argument(changeset, :edit_type) == "all" do
        reconcile_series(changeset, huddl, actor, changed_fields)
      else
        {:ok, huddl}
      end
    end)
  end

  defp reconcile_series(changeset, huddl, actor, changed_fields) do
    frequency = Ash.Changeset.get_argument(changeset, :frequency)

    # The update result doesn't carry loaded relationships, and API/GraphQL
    # callers may not have preloaded the template, so load it here.
    huddl = Ash.load!(huddl, :huddl_template, authorize?: false)

    case huddl.huddl_template do
      nil ->
        # Not part of a series; nothing to reconcile.
        {:ok, huddl}

      huddl_template ->
        changed_fields =
          if schedule_changed?(huddl_template, changeset, frequency) do
            [:schedule | changed_fields]
          else
            changed_fields
          end

        attrs =
          huddl_template
          |> series_schedule(changeset.data, huddl, frequency)
          |> Map.merge(%{frequency: frequency, source_huddl_id: huddl.id})
          |> put_repeat_until(changeset)

        {:ok, huddl_template} =
          huddl_template
          |> Ash.Changeset.for_update(:update, attrs, Huddlz.Audit.nested_opts(changeset))
          |> Ash.update(authorize?: false)

        # Synchronous: "edit all" is a rare organizer action, bounded by the
        # number of occurrences that already exist, and immediate consistency
        # is preferable here. Creating occurrences is the scheduled job's work.
        case RecurrenceHelper.reconcile_future_instances(huddl, huddl_template, actor, %{
               paper_trail_metadata: changeset.context[:paper_trail_metadata] || %{}
             }) do
          :ok ->
            notify_series(huddl, actor, changed_fields)
            {:ok, huddl}

          {:error, reason} ->
            {:error, reason}
        end
    end
  end

  # `nil` means two different things on this argument. For the web form, which
  # always submits the field, it means "boundless". For an API caller who only
  # changed the title, it means "not supplied". Only the argument's presence
  # tells them apart, so an omitted end date must never un-bound a series.
  defp put_repeat_until(attrs, changeset) do
    if repeat_until_supplied?(changeset) do
      Map.put(attrs, :repeat_until, Ash.Changeset.get_argument(changeset, :repeat_until))
    else
      attrs
    end
  end

  defp repeat_until_supplied?(changeset), do: Map.has_key?(changeset.arguments, :repeat_until)

  defp series_schedule(%{unit: :month} = template, original, huddl, frequency)
       when frequency in [nil, :monthly, "monthly"] do
    previous = HuddlTemplate.wall_clock_schedule(original)
    schedule = HuddlTemplate.wall_clock_schedule(huddl)

    if NaiveDateTime.to_date(previous.starts_at_local) ==
         NaiveDateTime.to_date(schedule.starts_at_local) do
      # A clamped February occurrence does not replace the selected monthly day.
      # Keep the anchor date while accepting edits to the local time and duration.
      days =
        Date.diff(
          NaiveDateTime.to_date(template.starts_at_local),
          NaiveDateTime.to_date(schedule.starts_at_local)
        )

      %{
        schedule
        | starts_at_local: NaiveDateTime.add(schedule.starts_at_local, days, :day),
          ends_at_local: NaiveDateTime.add(schedule.ends_at_local, days, :day)
      }
    else
      schedule
    end
  end

  defp series_schedule(_template, _original, huddl, _frequency) do
    HuddlTemplate.wall_clock_schedule(huddl)
  end

  defp schedule_changed?(template, changeset, frequency) do
    repeat_until_changed?(template, changeset) or frequency_changed?(template, frequency)
  end

  defp repeat_until_changed?(template, changeset) do
    if repeat_until_supplied?(changeset) do
      current = template.repeat_until && DateTime.to_date(template.repeat_until)
      current != Ash.Changeset.get_argument(changeset, :repeat_until)
    else
      false
    end
  end

  defp frequency_changed?(_template, nil), do: false

  defp frequency_changed?(template, frequency) do
    to_string(HuddlTemplate.cadence(template)) != to_string(frequency)
  end

  defp notify_series(_huddl, _actor, []), do: :ok

  defp notify_series(huddl, actor, changed_fields) do
    huddl = Ash.load!(huddl, :group, authorize?: false)
    actor_id = if actor, do: actor.id

    huddl
    |> RecipientHelpers.series_rsvp_targets(exclude: actor_id)
    |> Enum.each(fn %SeriesRsvpTarget{
                      user_id: user_id,
                      next_huddl: target,
                      calendar_huddlz: targets
                    } ->
      calendar_huddlz =
        targets
        |> Enum.map(&NotifyMeaningfulUpdate.payload(&1, huddl.group, changed_fields))

      payload =
        target
        |> NotifyMeaningfulUpdate.payload(huddl.group, changed_fields)
        |> Map.put("calendar_huddlz", calendar_huddlz)

      RecipientHelpers.deliver_each([user_id], :huddl_series_updated, payload)
    end)
  end
end
