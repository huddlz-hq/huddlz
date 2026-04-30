defmodule Huddlz.Notifications.Senders.GroupRoleChanged do
  @moduledoc """
  Sender for B4: a user's role within a group has changed.

  Sent to the user whose role changed. Activity category — preferences
  and the unsubscribe footer apply.

  Required payload keys:

    * `"group_id"` — used for fallback links.
    * `"group_name"` — display name of the group.
    * `"group_slug"` — slug for the group page URL.
    * `"previous_role"` — role string the user used to have.
    * `"new_role"` — role string the user now has.
  """

  @behaviour Huddlz.Notifications.Sender

  use HuddlzWeb, :verified_routes
  import Swoosh.Email

  alias Huddlz.Mailer
  alias Huddlz.Notifications.Footer
  alias Huddlz.Notifications.Senders.HtmlEscape

  @impl true
  def build(user, payload) do
    safe_name = HtmlEscape.escape(user.display_name)
    safe_group = HtmlEscape.escape(group_name(payload))
    safe_prev = HtmlEscape.escape(role_label(role_value(payload, "previous_role")))
    safe_new = HtmlEscape.escape(role_label(role_value(payload, "new_role")))
    group_url = group_url(payload)

    {footer_html, footer_text} = Footer.build(user, :group_role_changed)

    new()
    |> from(Mailer.from())
    |> to(to_string(user.email))
    |> subject("Your role in #{group_name(payload)} changed")
    |> html_body("""
    <p>Hi #{safe_name},</p>

    <p>Your role in <strong>#{safe_group}</strong> changed from
    <strong>#{safe_prev}</strong> to <strong>#{safe_new}</strong>.</p>

    <p>Visit the group at <a href="#{group_url}">#{group_url}</a>.</p>
    #{footer_html}
    """)
    |> text_body("""
    Hi #{user.display_name},

    Your role in "#{group_name(payload)}" changed from #{role_label(role_value(payload, "previous_role"))} to #{role_label(role_value(payload, "new_role"))}.

    Visit the group at #{group_url}.
    #{footer_text}
    """)
  end

  defp group_name(%{"group_name" => name}) when is_binary(name), do: name
  defp group_name(_), do: "the group"

  defp group_url(%{"group_slug" => slug}) when is_binary(slug), do: url(~p"/groups/#{slug}")
  defp group_url(_), do: url(~p"/groups")

  defp role_value(payload, key) do
    case Map.get(payload, key) do
      value when is_binary(value) -> value
      value when is_atom(value) -> Atom.to_string(value)
      _ -> ""
    end
  end

  defp role_label(""), do: "member"
  defp role_label(role), do: role
end
