defmodule Huddlz.Communities.Huddl.Changes.NotifyCancelled do
  @moduledoc """
  Enqueues C3 (huddl_cancelled) notifications when a published huddl is
  cancelled.

  Captures attendee user_ids and the huddl's display fields in
  `before_action`. The actor cancelling the huddl is excluded from the
  recipients. Fans out emails in `after_action` once the cancellation
  commits.
  """

  use Ash.Resource.Change

  alias Huddlz.Communities.Huddl.Changes.RecipientHelpers

  @impl true
  def change(changeset, _opts, _context) do
    changeset
    |> Ash.Changeset.before_action(&capture_recipients_and_payload/1)
    |> Ash.Changeset.after_action(&notify/2)
  end

  defp capture_recipients_and_payload(cs) do
    if notification_due?(cs) do
      capture_notification(cs)
    else
      cs
    end
  end

  defp capture_notification(cs) do
    huddl = Ash.load!(cs.data, [:group], authorize?: false)

    recipients =
      RecipientHelpers.rsvp_user_ids(huddl.id, exclude: RecipientHelpers.actor_id(cs))

    payload = %{
      "huddl_id" => huddl.id,
      "huddl_title" => to_string(huddl.title),
      "starts_at_iso" => DateTime.to_iso8601(huddl.starts_at),
      "group_name" => to_string(huddl.group.name),
      "group_slug" => to_string(huddl.group.slug),
      "cancellation_reason" =>
        Ash.Changeset.get_argument(cs, :cancellation_reason) || huddl.cancellation_reason
    }

    cs
    |> Ash.Changeset.put_context(:huddl_cancelled_recipients, recipients)
    |> Ash.Changeset.put_context(:huddl_cancelled_payload, payload)
  end

  defp notify(cs, huddl) do
    if notification_due?(cs) do
      recipients = cs.context[:huddl_cancelled_recipients] || []
      payload = cs.context[:huddl_cancelled_payload] || %{}
      RecipientHelpers.deliver_each(recipients, :huddl_cancelled, payload)
    end

    {:ok, huddl}
  end

  defp notification_due?(cs), do: cs.context[:lifecycle_transition] == :cancelled
end
