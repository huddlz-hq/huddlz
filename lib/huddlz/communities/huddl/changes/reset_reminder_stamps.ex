defmodule Huddlz.Communities.Huddl.Changes.ResetReminderStamps do
  @moduledoc """
  Clears `reminder_24h_sent_at` and `reminder_1h_sent_at` whenever
  `starts_at` changes on a huddl.

  Under the cron-driven reminder model, the sent-at columns are how
  the system remembers "this huddl already got its reminder, skip
  it." Resetting them on reschedule is the entire cancel-and-reissue
  story: the cron `due_for_*_reminder` filter picks the huddl up
  again at its new time.

  Operates only when `starts_at` is in the changeset attributes.
  """

  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    if Ash.Changeset.changing_attribute?(changeset, :starts_at) do
      changeset
      |> Ash.Changeset.force_change_attribute(:reminder_24h_sent_at, nil)
      |> Ash.Changeset.force_change_attribute(:reminder_1h_sent_at, nil)
    else
      changeset
    end
  end
end
