defmodule Huddlz.Notifications.Senders.HuddlCancelled do
  @moduledoc """
  Sender for C3: a huddl has been cancelled (destroyed).

  Sent to every user who had RSVP'd at the moment of cancellation.
  Transactional — preferences do not apply, no unsubscribe footer.
  People with travel plans need this no matter what their settings say.

  Required payload keys:

    * `"huddl_title"` — title of the huddl at time of cancellation.
    * `"starts_at_iso"` — ISO-8601 string of when it was supposed to start.
    * `"group_name"` — the host group's display name.
    * `"group_slug"` — the host group's slug, used to link back so the
      recipient can find replacement huddlz.
  """

  @behaviour Huddlz.Notifications.Sender

  use HuddlzWeb, :verified_routes
  import Swoosh.Email

  alias Huddlz.Mailer
  alias Huddlz.Notifications.Senders.HtmlEscape

  @impl true
  def build(user, payload) do
    safe_name = HtmlEscape.escape(user.display_name)
    safe_title = HtmlEscape.escape(huddl_title(payload))
    safe_group = HtmlEscape.escape(group_name(payload))
    when_text = format_starts_at(payload)
    safe_when = HtmlEscape.escape(when_text)
    group_url = group_url(payload)

    new()
    |> from(Mailer.from())
    |> to(to_string(user.email))
    |> subject("Cancelled: #{huddl_title(payload)}")
    |> html_body("""
    <p>Hi #{safe_name},</p>

    <p>The huddl <strong>#{safe_title}</strong> in
    <strong>#{safe_group}</strong>, scheduled for #{safe_when}, has
    been cancelled.</p>

    <p>If you'd made plans around this, you'll want to know. Sorry for
    the disruption.</p>

    <p>You can browse other upcoming huddlz at
    <a href="#{group_url}">#{group_url}</a>.</p>
    """)
    |> text_body("""
    Hi #{user.display_name},

    The huddl "#{huddl_title(payload)}" in "#{group_name(payload)}", scheduled for
    #{when_text}, has been cancelled.

    If you'd made plans around this, you'll want to know. Sorry for the disruption.

    You can browse other upcoming huddlz at #{group_url}.
    """)
  end

  defp huddl_title(%{"huddl_title" => title}) when is_binary(title), do: title
  defp huddl_title(_), do: "a huddl"

  defp group_name(%{"group_name" => name}) when is_binary(name), do: name
  defp group_name(_), do: "a group"

  defp group_url(%{"group_slug" => slug}) when is_binary(slug), do: url(~p"/groups/#{slug}")
  defp group_url(_), do: url(~p"/groups")

  defp format_starts_at(%{"starts_at_iso" => iso}) when is_binary(iso) do
    case DateTime.from_iso8601(iso) do
      {:ok, dt, _offset} -> Calendar.strftime(dt, "%a %b %-d, %Y at %-I:%M %p UTC")
      _ -> iso
    end
  end

  defp format_starts_at(_), do: "the scheduled time"
end
