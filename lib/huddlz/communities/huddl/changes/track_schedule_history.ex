defmodule Huddlz.Communities.Huddl.Changes.TrackScheduleHistory do
  @moduledoc "Retains the immediately previous published start and its local time zone."
  use Ash.Resource.Change

  alias Huddlz.Communities.Huddl.Changes.LockedHuddl

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.before_action(changeset, fn cs ->
      if Ash.Changeset.changing_attribute?(cs, :starts_at) do
        track_current_start(cs)
      else
        cs
      end
    end)
  end

  defp track_current_start(cs) do
    case LockedHuddl.fetch(cs.data.id) do
      {:ok, %{lifecycle_state: :published} = current} -> track_start(cs, current)
      {:ok, %{lifecycle_state: :draft}} -> cs
      {:ok, %{}} -> Ash.Changeset.add_error(cs, "This huddl can no longer be rescheduled.")
      error -> LockedHuddl.add_read_error(cs, error)
    end
  end

  defp track_start(changeset, current) do
    if DateTime.compare(Ash.Changeset.get_attribute(changeset, :starts_at), current.starts_at) !=
         :eq do
      changeset
      |> Ash.Changeset.force_change_attribute(:previous_starts_at, current.starts_at)
      |> Ash.Changeset.force_change_attribute(:previous_time_zone, current.time_zone)
    else
      changeset
    end
  end
end
