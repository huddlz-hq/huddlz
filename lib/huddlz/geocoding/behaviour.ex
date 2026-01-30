defmodule Huddlz.Geocoding.Behaviour do
  @moduledoc """
  Behaviour for geocoding services.

  Defines the contract for geocoding implementations, allowing for
  dependency injection and easy testing with Mox.
  """

  @type suggestion :: %{
          place_id: String.t(),
          description: String.t()
        }

  @type address_data :: %{
          formatted_address: String.t(),
          latitude: float(),
          longitude: float(),
          street_number: String.t() | nil,
          street_name: String.t() | nil,
          city: String.t() | nil,
          state: String.t() | nil,
          postal_code: String.t() | nil,
          country: String.t() | nil,
          country_name: String.t() | nil,
          place_id: String.t() | nil
        }

  @doc """
  Search for address suggestions based on a query string.

  Returns a list of suggestions with place_id and description.
  """
  @callback autocomplete(query :: String.t(), opts :: keyword()) ::
              {:ok, [suggestion()]} | {:error, term()}

  @doc """
  Get detailed address information for a place_id.

  Returns full address data including coordinates and address components.
  """
  @callback place_details(place_id :: String.t()) ::
              {:ok, address_data()} | {:error, term()}
end
