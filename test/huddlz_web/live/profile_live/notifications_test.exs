defmodule HuddlzWeb.ProfileLive.NotificationsTest do
  use HuddlzWeb.ConnCase, async: true

  import PhoenixTest
  import Huddlz.Test.Helpers.Authentication

  setup do
    user = create_user(%{display_name: "Settings User"})
    %{user: user}
  end

  describe "Notification preferences" do
    test "requires authentication", %{conn: conn} do
      conn
      |> visit("/profile/notifications")
      |> assert_path("/sign-in")
    end

    test "renders v3 chrome with Settings sidebar item active", %{conn: conn, user: user} do
      conn
      |> login(user)
      |> visit("/profile/notifications")
      |> assert_has("h1", text: "Settings")
      |> assert_has("aside.sidebar")
      |> assert_has(".sb-item.active", text: "Settings")
    end

    test "renders the three category panels in v3 chrome", %{conn: conn, user: user} do
      conn
      |> login(user)
      |> visit("/profile/notifications")
      |> assert_has(".panel-head h2", text: "Transactional")
      |> assert_has(".panel-head h2", text: "Activity")
      |> assert_has(".panel-head h2", text: "Digest")
    end

    test "transactional toggles are disabled", %{conn: conn, user: user} do
      conn
      |> login(user)
      |> visit("/profile/notifications")
      |> assert_has(".row .toggle input[type=checkbox][disabled]")
    end

    test "saving with an activity preference unchecked persists the change",
         %{conn: conn, user: user} do
      conn
      |> login(user)
      |> visit("/profile/notifications")
      |> uncheck("Confirmation when I RSVP to a huddl")
      |> click_button("Save preferences")
      |> assert_has("*", text: "Notification preferences saved")

      reloaded = Ash.get!(Huddlz.Accounts.User, user.id, actor: user)
      assert reloaded.notification_preferences["rsvp_confirmation"] == false
    end
  end
end
