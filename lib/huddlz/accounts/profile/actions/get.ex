defmodule Huddlz.Accounts.Profile.Actions.Get do
  @moduledoc false
  use Ash.Resource.Actions.Implementation

  @impl true
  def run(_input, _opts, context) do
    with {:ok, user} <- Huddlz.Accounts.get_current_user(scope: context) do
      {:ok,
       %{
         id: user.id,
         display_name: user.display_name,
         email: to_string(user.email),
         search_defaults: %{
           home_location: home_location(user),
           distance_miles: 25
         }
       }}
    end
  end

  defp home_location(%{home_latitude: lat, home_longitude: lng} = user)
       when is_number(lat) and is_number(lng) do
    if Huddlz.TimeZone.canonical?(user.home_time_zone) do
      %{
        label: user.home_location,
        latitude: lat,
        longitude: lng,
        time_zone: user.home_time_zone
      }
    end
  end

  defp home_location(_user), do: nil
end
