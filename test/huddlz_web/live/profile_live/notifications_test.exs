defmodule HuddlzWeb.ProfileLive.NotificationsTest do
  use HuddlzWeb.ConnCase, async: true

  import PhoenixTest
  import Huddlz.Test.Helpers.Authentication

  setup do
    user = create_user(%{display_name: "Preferences User"})
    %{user: user}
  end

  describe "Notification preferences" do
    test "requires authentication", %{conn: conn} do
      conn
      |> visit("/profile/notifications")
      |> assert_path("/sign-in")
    end

    test "renders v3 chrome with the Notifications sidebar item active", %{conn: conn, user: user} do
      conn
      |> login(user)
      |> visit("/profile/notifications")
      |> assert_has("h1", text: "Notifications")
      |> assert_has("aside.sidebar")
      |> assert_has(".sb-item.active", text: "Notifications")
    end

    test "renders the three category panels in v3 chrome", %{conn: conn, user: user} do
      conn
      |> login(user)
      |> visit("/profile/notifications")
      |> assert_has(".panel-head h2", text: "Activity")
      |> assert_has(".panel-head h2", text: "Digests")
      |> assert_has(".panel-head h2", text: "Always sent")
    end

    test "lists the essentials without switches", %{conn: conn, user: user} do
      conn
      |> login(user)
      |> visit("/profile/notifications")
      |> assert_has("#always-sent li", text: "Password changed")
      |> refute_has("input[role=switch][name='prefs[password_changed]']")
      |> refute_has("button", text: "Save")
    end

    test "flipping a switch saves that preference on its own", %{conn: conn, user: user} do
      conn
      |> login(user)
      |> visit("/profile/notifications")
      |> uncheck("Confirmation when I RSVP to a huddl")
      |> assert_has("[role=status]", text: "Saved")
      |> check("Weekly digest of upcoming huddlz")

      reloaded = Ash.get!(Huddlz.Accounts.User, user.id, actor: user)
      assert reloaded.notification_preferences["rsvp_confirmation"] == false
      assert reloaded.notification_preferences["weekly_digest"] == true

      conn
      |> login(user)
      |> visit("/profile/notifications")
      |> assert_has("input[role=switch][name='prefs[rsvp_confirmation]'][aria-checked=false]")
      |> assert_has("input[role=switch][name='prefs[weekly_digest]'][aria-checked=true]")
    end
  end
end
