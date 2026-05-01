defmodule Huddlz.Notifications.Senders.HuddlSeriesUpdated do
  @moduledoc """
  Sender for C4: a recurring huddl series was modified (the editor
  chose `edit_type: "all"`).

  Sent to the RSVPs of the *next* upcoming instance in the series,
  not to every instance's RSVPs — subsequent instances rely on their
  own D1/D2 reminders to surface the new schedule. Activity category
  — preferences and the unsubscribe footer apply.

  Required payload keys are the same as C2 (`huddl_id`,
  `huddl_title`, `starts_at_iso`, `group_name`, `group_slug`,
  `changed_fields`), but the values describe the next-instance row
  rather than the row that triggered the edit.
  """

  @behaviour Huddlz.Notifications.Sender

  use HuddlzWeb, :verified_routes
  import Swoosh.Email

  alias Huddlz.Mailer
  alias Huddlz.Notifications.Footer
  alias Huddlz.Notifications.Senders.HeaderSafe
  alias Huddlz.Notifications.Senders.HtmlEscape

  @impl true
  def build(user, payload) do
    safe_name = HtmlEscape.escape(user.display_name)
    safe_title = HtmlEscape.escape(huddl_title(payload))
    safe_group = HtmlEscape.escape(group_name(payload))
    when_text = format_starts_at(payload)
    safe_when = HtmlEscape.escape(when_text)
    safe_changed = HtmlEscape.escape(changed_summary(payload))
    huddl_url = huddl_url(payload)

    {footer_html, footer_text} = Footer.build(user, :huddl_series_updated)

    new()
    |> from(Mailer.from())
    |> to(to_string(user.email))
    |> subject(HeaderSafe.safe("Recurring series updated: #{huddl_title(payload)}"))
    |> html_body("""
    <p>Hi #{safe_name},</p>

    <p>The recurring huddl series in <strong>#{safe_group}</strong>
    has been updated.</p>

    <p><strong>What changed:</strong> #{safe_changed}.</p>

    <p>Your next upcoming instance, <strong>#{safe_title}</strong>,
    is now scheduled for #{safe_when}. See it at
    <a href="#{huddl_url}">#{huddl_url}</a>.</p>

    <p>Future instances in the series will be covered by their own
    24-hour and 1-hour reminders.</p>
    #{footer_html}
    """)
    |> text_body("""
    Hi #{user.display_name},

    The recurring huddl series in "#{group_name(payload)}" has been updated.

    What changed: #{changed_summary(payload)}.

    Your next upcoming instance, "#{huddl_title(payload)}", is now scheduled for
    #{when_text}. See it at #{huddl_url}.

    Future instances in the series will be covered by their own 24-hour and
    1-hour reminders.
    #{footer_text}
    """)
  end

  defp huddl_title(%{"huddl_title" => title}) when is_binary(title), do: title
  defp huddl_title(_), do: "the next instance"

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

  defp changed_summary(%{"changed_fields" => fields}) when is_list(fields) and fields != [] do
    Enum.map_join(fields, ", ", &humanize_field/1)
  end

  defp changed_summary(_), do: "huddl details"

  defp humanize_field("title"), do: "the title"
  defp humanize_field("starts_at"), do: "the start time"
  defp humanize_field("ends_at"), do: "the end time"
  defp humanize_field("physical_location"), do: "the location"
  defp humanize_field("virtual_link"), do: "the virtual link"
  defp humanize_field(other) when is_binary(other), do: other
end
