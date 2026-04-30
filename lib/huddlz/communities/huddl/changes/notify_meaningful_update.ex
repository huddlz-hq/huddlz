defmodule Huddlz.Communities.Huddl.Changes.NotifyMeaningfulUpdate do
  @moduledoc """
  Enqueues C2 (huddl_updated) notifications when a huddl is edited
  in a way that affects an attendee's plans — i.e. one of `:title`,
  `:starts_at`, `:ends_at`, `:physical_location`, or `:virtual_link`
  is in the changeset. Cosmetic edits (description, thumbnail, etc.)
  do not trigger an email.

  Recipients are the current RSVPs at the moment the update commits,
  excluding the actor.

  C4 (huddl_series_updated, recipients = next-upcoming-instance RSVPs
  when `edit_type == "all"`) is layered into this same module in a
  follow-up commit.
  """

  use Ash.Resource.Change

  alias Huddlz.Accounts.User
  alias Huddlz.Communities.Huddl.Changes.RecipientHelpers
  alias Huddlz.Notifications

  @meaningful_attrs [:title, :starts_at, :ends_at, :physical_location, :virtual_link]

  @impl true
  def change(changeset, _opts, _context) do
    changed_fields =
      Enum.filter(@meaningful_attrs, &Ash.Changeset.changing_attribute?(changeset, &1))

    if changed_fields == [] do
      changeset
    else
      changeset
      |> Ash.Changeset.put_context(:huddl_updated_changed_fields, changed_fields)
      |> Ash.Changeset.after_action(&notify/2)
    end
  end

  defp notify(cs, huddl) do
    huddl = Ash.load!(huddl, [:group], authorize?: false)
    changed_fields = cs.context[:huddl_updated_changed_fields] || []

    recipients =
      RecipientHelpers.rsvp_user_ids(huddl.id, exclude: RecipientHelpers.actor_id(cs))

    payload = %{
      "huddl_id" => huddl.id,
      "huddl_title" => to_string(huddl.title),
      "starts_at_iso" => DateTime.to_iso8601(huddl.starts_at),
      "group_name" => to_string(huddl.group.name),
      "group_slug" => to_string(huddl.group.slug),
      "changed_fields" => Enum.map(changed_fields, &Atom.to_string/1)
    }

    for user_id <- recipients do
      case Ash.get(User, user_id, authorize?: false) do
        {:ok, user} -> Notifications.deliver_async(user, :huddl_updated, payload)
        _ -> :noop
      end
    end

    {:ok, huddl}
  end
end
