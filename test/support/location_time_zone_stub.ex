defmodule Huddlz.LocationTimeZoneStub do
  @moduledoc """
  Default Location time-zone resolver used by tests.
  """

  @behaviour Huddlz.LocationTimeZone

  @zones %{
    {30.27, -97.74} => "America/Chicago",
    {30.28, -97.75} => "America/Chicago",
    {32.78, -96.8} => "America/Chicago",
    {29.89, -81.31} => "America/New_York",
    {37.77, -122.42} => "America/Los_Angeles",
    {40.71, -74.01} => "America/New_York",
    {39.74, -104.99} => "America/Denver",
    {33.45, -112.07} => "America/Phoenix",
    {29.76, -95.37} => "America/Chicago",
    {0.0, 0.0} => "Etc/UTC"
  }

  @impl true
  def resolve(latitude, longitude) do
    latitude
    |> then(&{Float.round(&1, 2), Float.round(longitude, 2)})
    |> then(&Map.fetch(@zones, &1))
    |> normalize_result()
  end

  defp normalize_result({:ok, time_zone}), do: {:ok, time_zone}
  defp normalize_result(:error), do: {:error, :not_found}
end
