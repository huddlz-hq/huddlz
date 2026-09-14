defmodule Huddlz.Communities.HuddlAttendee.Calculations.PictureUrl do
  @moduledoc """
  Resolves the person's current profile picture to a URL a page or an API
  client can fetch, so a list of people going never has to expose the user.
  """
  use Ash.Resource.Calculation

  @impl true
  def load(_query, _opts, _context), do: [user: [:current_profile_picture_url, :suspended_at]]

  @impl true
  def calculate(records, _opts, _context) do
    Enum.map(records, fn
      %{user: %{suspended_at: %DateTime{}}} -> nil
      %{user: user} -> picture_url(user.current_profile_picture_url)
    end)
  end

  defp picture_url(nil), do: nil

  defp picture_url(path) do
    HuddlzWeb.Endpoint.url()
    |> URI.merge(Huddlz.Storage.url(path))
    |> URI.to_string()
  end
end
