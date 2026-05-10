defmodule HuddlzWeb.Avatar do
  @moduledoc """
  Tiny helpers for rendering user avatars. `picture_url/1` returns the user's
  uploaded image when present, `initials/1` returns up-to-two display-name
  initials. Both fall through to `nil` so callers can decide what the empty
  state looks like (initials, blank gradient, etc.).

  Shared by the v3 sidebar (`.sb-user`) and the `/profile` `.big-avatar`.
  """

  alias Huddlz.Storage.ProfilePictures

  @doc "Returns the user's current profile picture URL, or nil."
  def picture_url(%{current_profile_picture_url: path}) when is_binary(path) and path != "",
    do: ProfilePictures.url(path)

  def picture_url(_), do: nil

  @doc "Returns the user's display-name initials (up to 2 chars), or nil."
  def initials(%{display_name: name}) when is_binary(name) and name != "" do
    name
    |> String.trim()
    |> String.split(~r/\s+/)
    |> Enum.take(2)
    |> Enum.map_join(&String.first/1)
    |> String.upcase()
  end

  def initials(_), do: nil
end
