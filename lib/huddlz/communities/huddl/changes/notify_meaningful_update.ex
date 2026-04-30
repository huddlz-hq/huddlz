defmodule Huddlz.Communities.Huddl.Changes.NotifyMeaningfulUpdate do
  @moduledoc """
  Enqueues notifications when a huddl is edited in a way that affects
  an attendee's plans — i.e. one of `:title`, `:starts_at`, `:ends_at`,
  `:physical_location`, or `:virtual_link` is in the changeset.
  Cosmetic edits (description, thumbnail, etc.) do not trigger an
  email.

  Branches on the `edit_type` action argument:

    * `"instance"` (default) — C2: fan out `:huddl_updated` to the
      current huddl's RSVPs, excluding the actor.
    * `"all"` — C4: `EditRecurringHuddlz` has regenerated every
      future instance in the series. Fan out
      `:huddl_series_updated` to the RSVPs of the *next upcoming
      instance only*, excluding the actor. Subsequent instances rely
      on their own D1/D2 reminders.

  Both branches use the same "meaningful field" gate.
  """

  use Ash.Resource.Change

  require Ash.Query

  alias Huddlz.Accounts.User
  alias Huddlz.Communities.Huddl
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
    case Ash.Changeset.get_argument(cs, :edit_type) do
      "all" -> notify_series(cs, huddl)
      _ -> notify_instance(cs, huddl)
    end
  end

  defp notify_instance(cs, huddl) do
    huddl = Ash.load!(huddl, [:group], authorize?: false)
    changed_fields = cs.context[:huddl_updated_changed_fields] || []

    recipients =
      RecipientHelpers.rsvp_user_ids(huddl.id, exclude: RecipientHelpers.actor_id(cs))

    payload = base_payload(huddl, changed_fields)

    deliver_each(recipients, :huddl_updated, payload)

    {:ok, huddl}
  end

  defp notify_series(cs, huddl) do
    case fetch_next_upcoming_instance(huddl) do
      nil ->
        {:ok, huddl}

      next ->
        next = Ash.load!(next, [:group], authorize?: false)
        changed_fields = cs.context[:huddl_updated_changed_fields] || []

        recipients =
          RecipientHelpers.rsvp_user_ids(next.id, exclude: RecipientHelpers.actor_id(cs))

        payload = base_payload(next, changed_fields)

        deliver_each(recipients, :huddl_series_updated, payload)

        {:ok, huddl}
    end
  end

  defp fetch_next_upcoming_instance(%Huddl{huddl_template_id: nil}), do: nil

  defp fetch_next_upcoming_instance(%Huddl{huddl_template_id: template_id}) do
    Huddl
    |> Ash.Query.filter(huddl_template_id == ^template_id and starts_at > now())
    |> Ash.Query.sort(starts_at: :asc)
    |> Ash.Query.limit(1)
    |> Ash.read_one!(authorize?: false)
  end

  defp base_payload(huddl, changed_fields) do
    %{
      "huddl_id" => huddl.id,
      "huddl_title" => to_string(huddl.title),
      "starts_at_iso" => DateTime.to_iso8601(huddl.starts_at),
      "group_name" => to_string(huddl.group.name),
      "group_slug" => to_string(huddl.group.slug),
      "changed_fields" => Enum.map(changed_fields, &Atom.to_string/1)
    }
  end

  defp deliver_each(user_ids, trigger, payload) do
    for user_id <- user_ids do
      case Ash.get(User, user_id, authorize?: false) do
        {:ok, user} -> Notifications.deliver_async(user, trigger, payload)
        _ -> :noop
      end
    end
  end
end
