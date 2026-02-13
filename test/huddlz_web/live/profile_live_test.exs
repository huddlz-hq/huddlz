defmodule HuddlzWeb.ProfileLiveTest do
  use HuddlzWeb.ConnCase, async: true

  import Mox
  import PhoenixTest
  import Huddlz.Test.Helpers.Authentication

  setup :verify_on_exit!

  setup do
    user = create_user(%{display_name: "Test User"})
    %{user: user}
  end

  describe "Profile page" do
    test "requires authentication", %{conn: conn} do
      conn
      |> visit("/profile")
      |> assert_path("/sign-in")
    end

    test "displays user profile when authenticated", %{conn: conn, user: user} do
      conn
      |> login(user)
      |> visit("/profile")
      |> assert_has("h1", text: "Profile Settings")
      |> assert_has("h2", text: "Display Name")
      |> assert_has("*", text: user.display_name)
      |> assert_has("*", text: to_string(user.email))
    end

    test "shows the profile form", %{conn: conn, user: user} do
      conn
      |> login(user)
      |> visit("/profile")
      |> assert_has("form")
      |> assert_has("input[name=\"form[display_name]\"]")
      |> assert_has("button[type=\"submit\"]", text: "Save Changes")
    end

    test "updates display name successfully", %{conn: conn, user: user} do
      new_name = "Updated Test Name"

      conn
      |> login(user)
      |> visit("/profile")
      |> fill_in("Display Name", with: new_name)
      |> click_button("Save Changes")
      |> assert_has("*", text: "Display name updated successfully")
      |> assert_has(~s|input[name="form[display_name]"][value="#{new_name}"]|)
    end

    test "validates display name length", %{conn: conn, user: user} do
      session =
        conn
        |> login(user)
        |> visit("/profile")

      # Test empty (not allowed)
      session
      |> fill_in("Display Name", with: "")
      |> click_button("Save Changes")
      |> assert_has("*", text: "Failed to update display name")

      # Test too long (> 30 chars)
      long_name = String.duplicate("a", 31)

      session
      |> fill_in("Display Name", with: long_name)
      |> click_button("Save Changes")
      |> assert_has("*", text: "Failed to update display name")

      # Test single character (should be allowed)
      session
      |> fill_in("Display Name", with: "A")
      |> click_button("Save Changes")
      |> assert_has("*", text: "Display name updated successfully")
    end

    test "display name validation on change", %{conn: conn, user: user} do
      conn
      |> login(user)
      |> visit("/profile")
      |> fill_in("Display Name", with: "")
      |> assert_has("form")
    end
  end

  describe "Home location" do
    test "shows home location form", %{conn: conn, user: user} do
      conn
      |> login(user)
      |> visit("/profile")
      |> assert_has("h2", text: "Home Location")
      |> assert_has("input[name=\"form[home_location]\"]")
      |> assert_has("button", text: "Save Location")
    end

    test "shows suggestions when typing", %{conn: conn, user: user} do
      stub(Huddlz.MockPlaces, :autocomplete, fn "saint", _token ->
        {:ok,
         [
           %{
             place_id: "p1",
             display_text: "Saint Augustine, FL, USA",
             main_text: "Saint Augustine",
             secondary_text: "FL, USA"
           }
         ]}
      end)

      conn
      |> login(user)
      |> visit("/profile")
      |> fill_in("City / Region", with: "saint")
      |> assert_has("button", text: "Saint Augustine")
    end

    test "selecting a suggestion and saving", %{conn: conn, user: user} do
      stub(Huddlz.MockPlaces, :autocomplete, fn "saint", _token ->
        {:ok,
         [
           %{
             place_id: "p1",
             display_text: "Saint Augustine, FL, USA",
             main_text: "Saint Augustine",
             secondary_text: "FL, USA"
           }
         ]}
      end)

      stub(Huddlz.MockPlaces, :place_details, fn "p1", _token ->
        {:ok, %{latitude: 29.89, longitude: -81.31}}
      end)

      conn
      |> login(user)
      |> visit("/profile")
      |> fill_in("City / Region", with: "saint")
      |> click_button("Saint Augustine")
      |> click_button("Save Location")
      |> assert_has("*", text: "Home location updated")
    end

    test "fallback to geocoding when user types without selecting", %{conn: conn, user: user} do
      stub(Huddlz.MockGeocoding, :geocode, fn "Austin, TX" ->
        {:ok, %{latitude: 30.27, longitude: -97.74}}
      end)

      conn
      |> login(user)
      |> visit("/profile")
      |> fill_in("City / Region", with: "Austin, TX")
      |> click_button("Save Location")
      |> assert_has("*", text: "Home location updated")
    end

    test "shows error when geocoding fallback fails", %{conn: conn, user: user} do
      stub(Huddlz.MockGeocoding, :geocode, fn _address ->
        {:error, {:request_failed, :timeout}}
      end)

      conn
      |> login(user)
      |> visit("/profile")
      |> fill_in("City / Region", with: "Austin, TX")
      |> click_button("Save Location")
      |> assert_has("p", text: "Location search is currently unavailable")
    end

    test "handles autocomplete API errors", %{conn: conn, user: user} do
      stub(Huddlz.MockPlaces, :autocomplete, fn _, _token ->
        {:error, {:request_failed, :timeout}}
      end)

      conn
      |> login(user)
      |> visit("/profile")
      |> fill_in("City / Region", with: "austin")
      |> assert_has("p", text: "Location search is currently unavailable")
    end

    test "clears error when user types in location field", %{conn: conn, user: user} do
      stub(Huddlz.MockPlaces, :autocomplete, fn _, _token ->
        {:error, {:request_failed, :timeout}}
      end)

      conn
      |> login(user)
      |> visit("/profile")
      |> fill_in("City / Region", with: "bad location")
      |> assert_has("p", text: "Location search is currently unavailable")

      # Stub returns ok now — typing clears the error
      stub(Huddlz.MockPlaces, :autocomplete, fn _, _token -> {:ok, []} end)

      conn
      |> login(user)
      |> visit("/profile")
      |> fill_in("City / Region", with: "trying again")
      |> refute_has("p", text: "Location search is currently unavailable")
    end
  end
end
