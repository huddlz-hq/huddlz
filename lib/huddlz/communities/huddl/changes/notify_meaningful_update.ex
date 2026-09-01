defmodule Huddlz.Communities.Huddl.Changes.NotifyMeaningfulUpdate do
  @moduledoc """
  Enqueues notifications when a huddl is edited in a way that affects an
  attendee's plans — i.e. one of `:title`, `:starts_at`, `:ends_at`,
  `:physical_location`, `:virtual_link`, `:max_attendees`, or `:is_private` is
  in the changeset. Cosmetic edits (description, thumbnail, etc.) do not
  trigger a notification.

  Emails everyone who has RSVP'd to the huddl (except the person making the edit)
  to tell them it changed. Whole-series edits are handled by
  `EditRecurringHuddlz`, which sends one C4 summary per affected person instead
  of allowing this C2 notifier to fan out once per occurrence.
  """

  use Ash.Resource.Change

  alias Huddlz.Communities.Huddl.Changes.NotificationPayload
  alias Huddlz.Communities.Huddl.Changes.RecipientHelpers

  @attendee_affecting_attrs [
    :title,
    :starts_at,
    :ends_at,
    :physical_location,
    :virtual_link,
    :max_attendees,
    :is_private
  ]

  @impl true
  def change(changeset, _opts, _context) do
    changed_fields = changed_fields(changeset)

    if changed_fields == [] or series_edit?(changeset) or suppressed?(changeset) do
      changeset
    else
      changeset
      |> Ash.Changeset.put_context(:huddl_updated_changed_fields, changed_fields)
      |> Ash.Changeset.after_action(&notify/2)
    end
  end

  @doc false
  @spec changed_fields(Ash.Changeset.t()) :: [atom()]
  def changed_fields(changeset) do
    Enum.filter(@attendee_affecting_attrs, fn attribute ->
      Ash.Changeset.changing_attribute?(changeset, attribute)
    end)
  end

  @doc false
  @spec payload(struct(), struct(), [atom()]) :: map()
  def payload(huddl, group, changed_fields) do
    huddl
    |> NotificationPayload.schedule(group)
    |> Map.put("changed_fields", Enum.map(changed_fields, &Atom.to_string/1))
    |> use_accessible_target(huddl)
  end

  defp series_edit?(changeset), do: Ash.Changeset.get_argument(changeset, :edit_type) == "all"

  defp suppressed?(changeset) do
    Ash.Changeset.get_argument(changeset, :suppress_update_notification) == true
  end

  defp notify(cs, huddl) do
    huddl = Ash.load!(huddl, [:group], authorize?: false)
    changed_fields = cs.context[:huddl_updated_changed_fields] || []

    recipients =
      RecipientHelpers.rsvp_user_ids(huddl.id, exclude: RecipientHelpers.actor_id(cs))

    payload = payload(huddl, huddl.group, changed_fields)

    RecipientHelpers.deliver_each(recipients, :huddl_updated, payload)

    {:ok, huddl}
  end

  defp use_accessible_target(payload, %{is_private: true}),
    do: Map.put(payload, "target_path", "/notifications")

  defp use_accessible_target(payload, _huddl), do: payload
end
