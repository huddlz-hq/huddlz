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
      |> assert_has("*", text: "Critical account and huddl updates")
      |> assert_has(".panel-head h2", text: "Activity")
      |> assert_has(".panel-head h2", text: "Digest")
    end

    test "transactional toggles are disabled", %{conn: conn, user: user} do
      conn
      |> login(user)
      |> visit("/profile/notifications")
      |> assert_has(".row .toggle.is-locked input[type=checkbox][disabled]")
      |> assert_has(".row .toggle.is-locked .toggle-text", text: "Always on")
    end

    test "stacks the appearance and preference panels", %{conn: conn, user: user} do
      conn
      |> login(user)
      |> visit("/profile/notifications")
      |> assert_has(".settings-stack #appearance-form .panel .appearance-row .row-title",
        text: "Theme"
      )
      |> assert_has(".appearance-row .appearance-tabs label.scope-tab", count: 3)
      |> assert_has(".appearance-tabs label.scope-tab.is-active .hero-computer-desktop")
      |> assert_has(".appearance-tabs label.scope-tab .hero-sun")
      |> assert_has(".appearance-tabs label.scope-tab .hero-moon")
      |> assert_has(".settings-stack form.settings-stack .panel", count: 3)
      |> assert_has(".settings-stack .settings-actions button[type=submit]",
        text: "Save preferences"
      )
    end

    test "saving with an activity preference unchecked persists the change",
         %{conn: conn, user: user} do
      conn
      |> login(user)
      |> visit("/profile/notifications")
      |> uncheck("Confirmation when I RSVP to a huddl")
      |> check("Weekly digest of upcoming huddlz")
      |> click_button("Save preferences")
      |> assert_has("*", text: "Notification preferences saved")

      reloaded = Ash.get!(Huddlz.Accounts.User, user.id, actor: user)
      assert reloaded.notification_preferences["rsvp_confirmation"] == false
      assert reloaded.notification_preferences["weekly_digest"] == true

      conn
      |> login(user)
      |> visit("/profile/notifications")
      |> assert_has("#prefs-rsvp_confirmation:not([checked])")
      |> assert_has("#prefs-weekly_digest[checked]")
    end
  end
end
