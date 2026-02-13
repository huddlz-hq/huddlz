defmodule Huddlz.PlacesTest do
  use Huddlz.DataCase, async: true

  import Mox

  setup :verify_on_exit!

  describe "autocomplete/2" do
    test "delegates to adapter" do
      stub(Huddlz.MockPlaces, :autocomplete, fn "aus", _token ->
        {:ok,
         [
           %{
             place_id: "p1",
             display_text: "Austin, TX, USA",
             main_text: "Austin",
             secondary_text: "TX, USA"
           }
         ]}
      end)

      assert {:ok, [%{place_id: "p1"}]} = Huddlz.Places.autocomplete("aus", "token")
    end

    test "returns error from adapter" do
      stub(Huddlz.MockPlaces, :autocomplete, fn _, _token ->
        {:error, {:request_failed, :timeout}}
      end)

      assert {:error, {:request_failed, :timeout}} =
               Huddlz.Places.autocomplete("aus", "token")
    end
  end

  describe "place_details/2" do
    test "delegates to adapter" do
      stub(Huddlz.MockPlaces, :place_details, fn "p1", _token ->
        {:ok, %{latitude: 30.27, longitude: -97.74}}
      end)

      assert {:ok, %{latitude: 30.27, longitude: -97.74}} =
               Huddlz.Places.place_details("p1", "token")
    end

    test "returns error from adapter" do
      stub(Huddlz.MockPlaces, :place_details, fn _, _token ->
        {:error, :not_found}
      end)

      assert {:error, :not_found} = Huddlz.Places.place_details("p1", "token")
    end
  end

  describe "error_message/1" do
    test "returns message for :not_found" do
      assert Huddlz.Places.error_message(:not_found) == "Could not find that location."
    end

    test "returns message for other errors" do
      assert Huddlz.Places.error_message(:timeout) ==
               "Location search is currently unavailable."
    end
  end
end
