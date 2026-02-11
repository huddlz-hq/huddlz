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

    test "shows error when geocoding is unavailable", %{conn: conn, user: user} do
      stub(Huddlz.MockGeocoding, :geocode, fn _address -> {:error, :no_api_key} end)

      conn
      |> login(user)
      |> visit("/profile")
      |> fill_in("City / Region", with: "Austin, TX")
      |> click_button("Save Location")
      |> assert_has("p", text: "Location search is currently unavailable")
    end

    test "shows error when location is not found", %{conn: conn, user: user} do
      stub(Huddlz.MockGeocoding, :geocode, fn _address -> {:error, :not_found} end)

      conn
      |> login(user)
      |> visit("/profile")
      |> fill_in("City / Region", with: "xyznonexistent123")
      |> click_button("Save Location")
      |> assert_has("p", text: "Could not find that location")
    end

    test "saves location successfully when geocoding works", %{conn: conn, user: user} do
      stub(Huddlz.MockGeocoding, :geocode, fn "Austin, TX" ->
        {:ok, %{latitude: 30.2672, longitude: -97.7431}}
      end)

      conn
      |> login(user)
      |> visit("/profile")
      |> fill_in("City / Region", with: "Austin, TX")
      |> click_button("Save Location")
      |> assert_has("*", text: "Home location updated")
    end

    test "clears error when user types in location field", %{conn: conn, user: user} do
      stub(Huddlz.MockGeocoding, :geocode, fn _address -> {:error, :not_found} end)

      conn
      |> login(user)
      |> visit("/profile")
      |> fill_in("City / Region", with: "bad location")
      |> click_button("Save Location")
      |> assert_has("p", text: "Could not find that location")
      |> fill_in("City / Region", with: "trying again")
      |> refute_has("p", text: "Could not find that location")
    end
  end
end
