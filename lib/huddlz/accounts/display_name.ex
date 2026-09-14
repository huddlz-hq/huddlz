defmodule Huddlz.Accounts.DisplayName do
  @moduledoc """
  Recognizes contact links that do not belong in a display name.

  Bare domains use a checked-in IANA root-zone snapshot rather than treating every
  dotted name as a link. Refresh the snapshot from
  https://data.iana.org/TLD/tlds-alpha-by-domain.txt when new suffixes are needed.
  Recognition never resolves or visits a submitted address. Disguised advertising
  and ambiguous handles remain matters for moderation.
  """

  @external_resource Path.expand("../../../priv/validation/tlds-alpha-by-domain.txt", __DIR__)

  suffixes =
    @external_resource
    |> File.read!()
    |> String.split("\n", trim: true)
    |> Enum.reject(&String.starts_with?(&1, "#"))
    |> Enum.flat_map(fn suffix ->
      ascii = String.downcase(suffix)
      unicode = ascii |> String.to_charlist() |> :idna.decode() |> List.to_string()
      [ascii, unicode]
    end)
    |> Enum.uniq()
    |> Enum.map_join("|", &Regex.escape/1)

  label = ~S/[\p{L}\p{N}][\p{L}\p{M}\p{N}-]*/
  domain = ~S/(?:/ <> label <> ~S/\.)+(?:/ <> suffixes <> ~S/)(?![\p{L}\p{M}\p{N}-])/
  explicit_link = ~S"(?:[a-z][a-z0-9+.-]*://|www\.)\S+"
  email = ~S/[^\s@]+@[^\s@]+/

  @allowed_pattern Regex.compile!("\\A(?!.*(?:#{explicit_link}|#{domain}|#{email})).*\\z", "isu")

  def allowed_pattern, do: @allowed_pattern
end
