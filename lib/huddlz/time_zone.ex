defmodule Huddlz.TimeZone do
  @moduledoc """
  Validates IANA time-zone names received from trusted browser APIs or clients.
  """

  @reference_datetime ~U[2000-01-01 00:00:00Z]

  def valid?(time_zone) when is_binary(time_zone) do
    match?({:ok, _datetime}, DateTime.shift_zone(@reference_datetime, time_zone))
  end

  def valid?(_time_zone), do: false

  def from_connect_params(%{"timezone" => time_zone}) do
    if valid?(time_zone), do: time_zone
  end

  def from_connect_params(_params), do: nil

  def valid_or_utc(time_zone) do
    if valid?(time_zone), do: time_zone, else: "Etc/UTC"
  end
end
