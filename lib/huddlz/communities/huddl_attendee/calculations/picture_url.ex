defmodule Huddlz.Communities.HuddlAttendee.Calculations.PictureUrl do
  @moduledoc """
  Resolves the person's current profile picture to a URL a page or an API
  client can fetch, so a list of people going never has to expose the user.
  """
  use Ash.Resource.Calculation

  @impl true
  def load(_query, _opts, _context), do: [user: [:current_profile_picture_url]]

  @impl true
  def calculate(records, _opts, _context) do
    Enum.map(records, &picture_url(&1.user.current_profile_picture_url))
  end

  defp picture_url(nil), do: nil

  defp picture_url(path) do
    HuddlzWeb.Endpoint.url()
    |> URI.merge(Huddlz.Storage.url(path))
    |> URI.to_string()
  end
end
