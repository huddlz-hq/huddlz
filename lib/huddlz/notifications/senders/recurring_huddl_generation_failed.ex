defmodule Huddlz.Notifications.Senders.RecurringHuddlGenerationFailed do
  @moduledoc """
  Tells an organizer when all attempts to generate a recurring huddl series fail.

  This notification is transactional because the organizer must know that the
  future dates they requested were not created.
  """

  @behaviour Huddlz.Notifications.Sender

  import Swoosh.Email

  alias Huddlz.Mailer
  alias Huddlz.Notifications.Senders.HeaderSafe
  alias Huddlz.Notifications.Senders.HtmlEscape
  alias Huddlz.Notifications.Senders.Urls

  @impl true
  def build(user, payload) do
    safe_name = HtmlEscape.escape(user.display_name)
    safe_title = HtmlEscape.escape(huddl_title(payload))
    safe_group = HtmlEscape.escape(group_name(payload))
    huddl_url = Urls.huddl_url(payload)

    new()
    |> from(Mailer.from())
    |> to(to_string(user.email))
    |> subject(HeaderSafe.safe("Recurring dates need attention: #{huddl_title(payload)}"))
    |> html_body("""
    <p>Hi #{safe_name},</p>

    <p>We couldn't generate all recurring dates for
    <strong>#{safe_title}</strong> in <strong>#{safe_group}</strong>.</p>

    <p>The original huddl is still available. Review it at
    <a href="#{huddl_url}">#{huddl_url}</a>, then save the series again to retry.</p>
    """)
    |> text_body("""
    Hi #{user.display_name},

    We couldn't generate all recurring dates for "#{huddl_title(payload)}" in
    "#{group_name(payload)}".

    The original huddl is still available. Review it at #{huddl_url}, then save
    the series again to retry.
    """)
  end

  defp huddl_title(%{"huddl_title" => title}) when is_binary(title), do: title
  defp huddl_title(_), do: "your recurring huddl"

  defp group_name(%{"group_name" => name}) when is_binary(name), do: name
  defp group_name(_), do: "your group"
end
