defmodule Huddlz.PlacesStub do
  @moduledoc """
  Default stub implementation for Places in tests.
  Returns empty results for autocomplete and :not_found for place_details.
  Use Mox.expect/3 or Mox.stub/3 in individual tests to override.
  """
  @behaviour Huddlz.Places

  @impl true
  def autocomplete(_query, _session_token, _opts), do: {:ok, []}

  @impl true
  def place_details(_place_id, _session_token), do: {:error, :not_found}
end
