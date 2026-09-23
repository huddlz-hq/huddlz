defmodule Huddlz.Communities.GroupLocation.Changes.NormalizeAddress do
  @moduledoc """
  Tidies an organizer's address text: one kind of line break (browsers submit
  textareas with CRLF) and no surrounding whitespace.
  """
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    case Ash.Changeset.fetch_change(changeset, :address) do
      {:ok, address} when is_binary(address) ->
        normalized = address |> String.replace("\r\n", "\n") |> String.trim()
        Ash.Changeset.force_change_attribute(changeset, :address, normalized)

      _ ->
        changeset
    end
  end
end
