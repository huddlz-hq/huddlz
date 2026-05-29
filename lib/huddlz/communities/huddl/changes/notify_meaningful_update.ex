defmodule Huddlz.Communities.Huddl.Changes.NotifyMeaningfulUpdate do
  @moduledoc """
  Enqueues notifications when a huddl is edited in a way that affects an
  attendee's plans — i.e. one of `:title`, `:starts_at`, `:ends_at`,
  `:physical_location`, or `:virtual_link` is in the changeset. Cosmetic edits
  (description, thumbnail, etc.) do not trigger an email.

  Emails everyone who has RSVP'd to the huddl (except the person making the edit)
  to tell them it changed. This fires for both a single-huddl edit and an "edit
  all" on a series: the series edit updates each future occurrence through its
  own `:update`, so every changed occurrence emails its own attendees from here.

  In `docs/notifications.md` terms this is notification C2 (`:huddl_updated`). The
  per-series digest C4 (`:huddl_series_updated`) is deliberately not sent for now;
  its sender is kept for a possible future "one summary per attendee" option.
  """

  use Ash.Resource.Change

  alias Huddlz.Communities.Huddl.Changes.RecipientHelpers

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

    RecipientHelpers.deliver_each(recipients, :huddl_updated, payload)

    {:ok, huddl}
  end
end
