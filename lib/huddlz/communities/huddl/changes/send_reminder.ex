defmodule Huddlz.Communities.Huddl.Changes.SendReminder do
  @moduledoc """
  Stamps the relevant `reminder_*_sent_at` column and fans out
  `:huddl_reminder_24h` or `:huddl_reminder_1h` notifications to
  every current RSVP for the huddl.

  Invoked by the AshOban-scheduled `:send_24h_reminder` and
  `:send_1h_reminder` update actions on `Huddl`. Recipients are
  resolved at fire time so users who RSVP after the huddl was
  created still receive the reminder.

  Required option: `kind: :h24 | :h1`.
  """

  use Ash.Resource.Change

  alias Huddlz.Communities.Huddl.Changes.RecipientHelpers

  @impl true
  def change(changeset, opts, _context) do
    kind = Keyword.fetch!(opts, :kind)
    stamp_attr = stamp_attribute(kind)
    trigger = trigger_atom(kind)

    changeset
    |> Ash.Changeset.force_change_attribute(stamp_attr, DateTime.utc_now())
    |> Ash.Changeset.after_action(fn _cs, huddl -> fan_out(huddl, trigger) end)
  end

  defp fan_out(huddl, trigger) do
    user_ids = RecipientHelpers.rsvp_user_ids(huddl.id)

    payload = %{"huddl_id" => huddl.id}

    RecipientHelpers.deliver_each(user_ids, trigger, payload)

    {:ok, huddl}
  end

  defp stamp_attribute(:h24), do: :reminder_24h_sent_at
  defp stamp_attribute(:h1), do: :reminder_1h_sent_at

  defp trigger_atom(:h24), do: :huddl_reminder_24h
  defp trigger_atom(:h1), do: :huddl_reminder_1h
end
