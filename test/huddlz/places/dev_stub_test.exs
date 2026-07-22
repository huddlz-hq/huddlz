defmodule Huddlz.Places.DevStubTest do
  use ExUnit.Case, async: true

  alias Huddlz.Places.DevStub

  test "autocomplete returns all preset locations for any query" do
    assert {:ok, suggestions} = DevStub.autocomplete("anything", "token", [])
    assert length(suggestions) == 7
    assert Enum.any?(suggestions, &(&1.main_text == "San Francisco"))
  end

  test "place_details returns coordinates for a preset location" do
    assert {:ok, %{latitude: 30.2672, longitude: -97.7431}} =
             DevStub.place_details("dev_stub_austin", "token")
  end

  test "place_details rejects an unknown location" do
    assert {:error, :not_found} = DevStub.place_details("unknown", "token")
  end
end
