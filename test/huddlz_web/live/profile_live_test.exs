defmodule HuddlzWeb.ProfileLiveTest do
  use HuddlzWeb.ConnCase, async: true

  import PhoenixTest
  import Huddlz.Test.Helpers.Authentication

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
end
