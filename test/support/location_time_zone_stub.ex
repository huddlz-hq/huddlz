defmodule Huddlz.LocationTimeZoneStub do
  @moduledoc """
  Default Location time-zone resolver used by tests.
  """

  @behaviour Huddlz.LocationTimeZone

  @impl true
  def resolve(latitude, longitude) do
    case {Float.round(latitude, 2), Float.round(longitude, 2)} do
      {30.27, -97.74} -> {:ok, "America/Chicago"}
      {29.89, -81.31} -> {:ok, "America/New_York"}
      _ -> {:error, :not_found}
    end
  end
end
