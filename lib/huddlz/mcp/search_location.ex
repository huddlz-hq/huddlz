defmodule Huddlz.Mcp.SearchLocation do
  alias Ash.Error.Changes.InvalidArgument
  @moduledoc false

  def resolve(%{anywhere: true}, _context), do: {:ok, %{}}

  def resolve(%{latitude: lat, longitude: lng} = args, _context)
      when is_number(lat) and is_number(lng) do
    {:ok, %{search_latitude: lat, search_longitude: lng, distance_miles: args.distance_miles}}
  end

  def resolve(args, context) do
    if args[:latitude] || args[:longitude] do
      invalid_location("Provide both latitude and longitude.")
    else
      home_location(args, context)
    end
  end

  defp home_location(args, context) do
    with {:ok, profile} <- Huddlz.Accounts.get_profile(scope: context) do
      case profile.search_defaults.home_location do
        nil ->
          invalid_location(
            "No home search location is saved. Ask where to search, then provide latitude and longitude; use anywhere only if requested."
          )

        home ->
          {:ok,
           %{
             search_latitude: home.latitude,
             search_longitude: home.longitude,
             distance_miles: args.distance_miles
           }}
      end
    end
  end

  defp invalid_location(message) do
    {:error, InvalidArgument.exception(field: :latitude, message: message)}
  end
end
