defmodule Huddlz.LocationTimeZone.Google do
  @moduledoc """
  Google Maps Time Zone API implementation.
  """

  @behaviour Huddlz.LocationTimeZone

  @time_zone_url "https://maps.googleapis.com/maps/api/timezone/json"
  @req_options [receive_timeout: :timer.seconds(5), retry: false]

  @impl true
  def resolve(latitude, longitude) do
    opts =
      [
        params: [
          location: "#{latitude},#{longitude}",
          timestamp: DateTime.utc_now() |> DateTime.to_unix(),
          key: api_key()
        ]
      ] ++ @req_options ++ req_test_options()

    @time_zone_url
    |> Req.get(opts)
    |> parse_response()
  end

  defp parse_response(
         {:ok, %{status: 200, body: %{"status" => "OK", "timeZoneId" => time_zone}}}
       ),
       do: {:ok, time_zone}

  defp parse_response({:ok, %{status: 200, body: %{"status" => "ZERO_RESULTS"}}}),
    do: {:error, :not_found}

  defp parse_response({:ok, %{status: 200, body: %{"status" => status}}}),
    do: {:error, {:api_error, status}}

  defp parse_response({:ok, %{status: status, body: body}}),
    do: {:error, {:api_error, status, body}}

  defp parse_response({:error, reason}), do: {:error, {:request_failed, reason}}

  defp api_key, do: Application.get_env(:huddlz, :google_maps)[:api_key]

  defp req_test_options do
    case Application.get_env(:huddlz, :location_time_zone_req_plug) do
      nil -> []
      plug -> [plug: plug]
    end
  end
end
