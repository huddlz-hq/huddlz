defmodule Huddlz.Notifications.Senders.HeaderSafe do
  @moduledoc """
  Strip control characters from values that get interpolated into email
  header fields (Subject, etc.). User-controlled fields like
  `display_name`, `Group.name`, and `Huddl.title` have no format
  constraints preventing CR/LF, which on a poorly-behaved transport
  could fold or inject headers. Swoosh's mail layer handles most of
  this defensively, but explicit sanitization at the boundary is
  cheaper than auditing every transport.

  Plain-text and HTML bodies do not need this treatment; HTML bodies
  use `HtmlEscape`.
  """

  @doc """
  Replace any control character (CR, LF, tab, NUL, DEL, etc.) with a
  single space, then collapse whitespace runs and trim. Returns a
  plain string.

      iex> Huddlz.Notifications.Senders.HeaderSafe.safe("Alice\\r\\nBcc: x")
      "Alice Bcc: x"
  """
  @spec safe(term()) :: String.t()
  def safe(value) do
    value
    |> to_string()
    |> String.replace(~r/[[:cntrl:]]/u, " ")
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
  end
end
