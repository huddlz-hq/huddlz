defmodule Huddlz.Communities.Huddl.Changes.ApplyProvidedCoordinatesTest do
  use Huddlz.DataCase, async: true

  alias Huddlz.Communities.Group

  import Mox

  setup :verify_on_exit!

  describe "apply_provided_coordinates change" do
    setup do
      owner = generate(user(role: :user))
      {:ok, %{owner: owner}}
    end

    test "when provided_latitude and provided_longitude are given, sets coordinates and skips geocoding",
         %{owner: owner} do
      # Geocoding should NOT be called when coordinates are provided
      Mox.expect(Huddlz.MockGeocoding, :geocode, 0, fn _ ->
        {:ok, %{latitude: 0, longitude: 0}}
      end)

      assert {:ok, huddl} =
               Group
               |> Ash.Changeset.new()
               |> Ash.Changeset.set_argument(:provided_latitude, 30.27)
               |> Ash.Changeset.set_argument(:provided_longitude, -97.74)
               |> Ash.Changeset.for_create(:create_group, %{
                 name: "Austin Group",
                 description: "Test",
                 location: "100 Main St, Austin, TX",
                 is_public: true
               })
               |> Ash.create(actor: owner)

      assert huddl.latitude == 30.27
      assert huddl.longitude == -97.74
    end

    test "when coordinates NOT provided, geocoding runs normally",
         %{owner: owner} do
      Mox.expect(Huddlz.MockGeocoding, :geocode, fn "456 Oak Ave, Dallas, TX" ->
        {:ok, %{latitude: 32.78, longitude: -96.80}}
      end)

      assert {:ok, huddl} =
               Group
               |> Ash.Changeset.for_create(:create_group, %{
                 name: "Dallas Group",
                 description: "Test",
                 location: "456 Oak Ave, Dallas, TX",
                 is_public: true
               })
               |> Ash.create(actor: owner)

      assert huddl.latitude == 32.78
      assert huddl.longitude == -96.80
    end

    test "partial coordinates (only lat) are ignored, geocoding runs",
         %{owner: owner} do
      Mox.expect(Huddlz.MockGeocoding, :geocode, fn _ ->
        {:ok, %{latitude: 29.76, longitude: -95.37}}
      end)

      assert {:ok, huddl} =
               Group
               |> Ash.Changeset.new()
               |> Ash.Changeset.set_argument(:provided_latitude, 30.27)
               |> Ash.Changeset.for_create(:create_group, %{
                 name: "Houston Group",
                 description: "Test",
                 location: "789 Elm St, Houston, TX",
                 is_public: true
               })
               |> Ash.create(actor: owner)

      assert huddl.latitude == 29.76
      assert huddl.longitude == -95.37
    end
  end
end
