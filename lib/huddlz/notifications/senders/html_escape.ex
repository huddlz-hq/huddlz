defmodule Huddlz.Notifications.Senders.HtmlEscape do
  @moduledoc """
  Escape user-controlled values for safe interpolation into sender HTML bodies.

  Senders interpolate strings (display name, email addresses, etc.) directly
  into HTML heredocs, which means anything not pre-escaped becomes an XSS
  vector for whoever opens the email. Plain-text bodies do not need this
  treatment.

  See `docs/notifications.md` § Sender conventions.
  """

  @doc """
  HTML-escape an arbitrary value, returning a plain string.

      iex> Huddlz.Notifications.Senders.HtmlEscape.escape("<script>")
      "&lt;script&gt;"
  """
  @spec escape(term()) :: String.t()
  def escape(value) do
    value
    |> to_string()
    |> Phoenix.HTML.html_escape()
    |> Phoenix.HTML.safe_to_string()
  end
end
