defmodule Huddlz.Notifications.Senders.HuddlNew do
  @moduledoc """
  Sender for C1: a new huddl was scheduled in a group the recipient
  belongs to.

  Sent to every member of the group at the moment of creation,
  excluding the user who created it. Activity category — preferences
  and the unsubscribe footer apply.

  Required payload keys:

    * `"huddl_id"` — UUID, used to link to the huddl page.
    * `"huddl_title"` — display title.
    * `"starts_at_iso"` — ISO-8601 string of when it starts.
    * `"group_name"` — host group's display name.
    * `"group_slug"` — host group's slug, used to build the huddl URL.
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
    safe_title = HtmlEscape.escape(huddl_title(payload))
    safe_group = HtmlEscape.escape(group_name(payload))
    when_text = format_starts_at(payload)
    safe_when = HtmlEscape.escape(when_text)
    huddl_url = huddl_url(payload)

    {footer_html, footer_text} = Footer.build(user, :huddl_new)

    new()
    |> from(Mailer.from())
    |> to(to_string(user.email))
    |> subject("New huddl in #{group_name(payload)}: #{huddl_title(payload)}")
    |> html_body("""
    <p>Hi #{safe_name},</p>

    <p><strong>#{safe_group}</strong> just scheduled a new huddl:
    <strong>#{safe_title}</strong>, on #{safe_when}.</p>

    <p>RSVP if you can make it: <a href="#{huddl_url}">#{huddl_url}</a>.</p>
    #{footer_html}
    """)
    |> text_body("""
    Hi #{user.display_name},

    "#{group_name(payload)}" just scheduled a new huddl: "#{huddl_title(payload)}",
    on #{when_text}.

    RSVP if you can make it: #{huddl_url}.
    #{footer_text}
    """)
  end

  defp huddl_title(%{"huddl_title" => title}) when is_binary(title), do: title
  defp huddl_title(_), do: "a new huddl"

  defp group_name(%{"group_name" => name}) when is_binary(name), do: name
  defp group_name(_), do: "a group"

  defp huddl_url(%{"group_slug" => slug, "huddl_id" => id})
       when is_binary(slug) and is_binary(id) do
    url(~p"/groups/#{slug}/huddlz/#{id}")
  end

  defp huddl_url(%{"group_slug" => slug}) when is_binary(slug), do: url(~p"/groups/#{slug}")
  defp huddl_url(_), do: url(~p"/")

  defp format_starts_at(%{"starts_at_iso" => iso}) when is_binary(iso) do
    case DateTime.from_iso8601(iso) do
      {:ok, dt, _offset} -> Calendar.strftime(dt, "%a %b %-d, %Y at %-I:%M %p UTC")
      _ -> iso
    end
  end

  defp format_starts_at(_), do: "the scheduled time"
end
