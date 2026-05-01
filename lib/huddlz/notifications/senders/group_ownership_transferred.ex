defmodule Huddlz.Notifications.Senders.GroupOwnershipTransferred do
  @moduledoc """
  Sender for B7: ownership of a group was transferred.

  Sent to both the previous owner and the new owner. Transactional —
  preferences do not apply, no unsubscribe footer.

  Required payload keys:

    * `"group_id"` — used for fallback links.
    * `"group_name"` — display name of the group.
    * `"group_slug"` — slug for the group page URL.
    * `"role"` — `"previous_owner"` or `"new_owner"` — used to pick the
      correct copy for the recipient.
    * `"new_owner_display_name"` — name of the new owner (used when
      addressing the previous owner).
    * `"previous_owner_display_name"` — name of the previous owner
      (used when addressing the new owner).
  """

  @behaviour Huddlz.Notifications.Sender

  use HuddlzWeb, :verified_routes
  import Swoosh.Email

  alias Huddlz.Mailer
  alias Huddlz.Notifications.Senders.HeaderSafe
  alias Huddlz.Notifications.Senders.HtmlEscape

  @impl true
  def build(user, payload) do
    role = payload["role"] || "previous_owner"

    case role do
      "new_owner" -> build_new_owner(user, payload)
      _ -> build_previous_owner(user, payload)
    end
  end

  defp build_previous_owner(user, payload) do
    safe_name = HtmlEscape.escape(user.display_name)
    safe_group = HtmlEscape.escape(group_name(payload))
    safe_new_owner = HtmlEscape.escape(payload["new_owner_display_name"] || "another member")
    group_url = group_url(payload)

    new()
    |> from(Mailer.from())
    |> to(to_string(user.email))
    |> subject(HeaderSafe.safe("You transferred #{group_name(payload)} to a new owner"))
    |> html_body("""
    <p>Hi #{safe_name},</p>

    <p>You've transferred ownership of <strong>#{safe_group}</strong> to
    <strong>#{safe_new_owner}</strong>. You're still part of the group as
    an organizer and can step away or rejoin anytime.</p>

    <p>The group page is at <a href="#{group_url}">#{group_url}</a>.</p>
    """)
    |> text_body("""
    Hi #{user.display_name},

    You've transferred ownership of "#{group_name(payload)}" to #{payload["new_owner_display_name"] || "another member"}.
    You're still part of the group as an organizer and can step away or rejoin anytime.

    The group page is at #{group_url}.
    """)
  end

  defp build_new_owner(user, payload) do
    safe_name = HtmlEscape.escape(user.display_name)
    safe_group = HtmlEscape.escape(group_name(payload))

    safe_prev_owner =
      HtmlEscape.escape(payload["previous_owner_display_name"] || "the previous owner")

    group_url = group_url(payload)

    new()
    |> from(Mailer.from())
    |> to(to_string(user.email))
    |> subject(HeaderSafe.safe("You're the new owner of #{group_name(payload)}"))
    |> html_body("""
    <p>Hi #{safe_name},</p>

    <p><strong>#{safe_prev_owner}</strong> has transferred ownership of
    <strong>#{safe_group}</strong> to you. The group is now yours to
    manage.</p>

    <p>Open the group page at <a href="#{group_url}">#{group_url}</a> to
    review members, organizers, and upcoming huddlz.</p>
    """)
    |> text_body("""
    Hi #{user.display_name},

    #{payload["previous_owner_display_name"] || "The previous owner"} has transferred ownership of "#{group_name(payload)}" to you.
    The group is now yours to manage.

    Open the group page at #{group_url} to review members, organizers, and upcoming huddlz.
    """)
  end

  defp group_name(%{"group_name" => name}) when is_binary(name), do: name
  defp group_name(_), do: "the group"

  defp group_url(%{"group_slug" => slug}) when is_binary(slug), do: url(~p"/groups/#{slug}")
  defp group_url(_), do: url(~p"/groups")
end
