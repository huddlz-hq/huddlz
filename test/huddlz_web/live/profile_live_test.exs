defmodule HuddlzWeb.ProfileLiveTest do
  use HuddlzWeb.ConnCase, async: true
  use Oban.Testing, repo: Huddlz.Repo

  import Mox
  import PhoenixTest
  import Phoenix.LiveViewTest
  import Huddlz.Test.Helpers.Authentication

  alias Huddlz.Accounts.User
  alias Huddlz.Notifications.DeliverWorker

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

    test "renders v3 chrome with Profile sidebar item active", %{conn: conn, user: user} do
      conn
      |> login(user)
      |> visit("/profile")
      |> assert_has("h1", text: "Profile")
      |> assert_has("aside.sidebar")
      |> assert_has(".sb-item.active", text: "Profile")
      |> assert_has(
        "#sign-out-link[href='/sign-out'][data-method='delete'][data-csrf][aria-label='Sign out']",
        text: "Sign out"
      )
    end

    test "does not show sign out in signed-out navigation", %{conn: conn} do
      conn
      |> visit("/discover")
      |> refute_has("a", text: "Sign out")
    end

    test "sidebar shows initials when the user has no profile picture", %{
      conn: conn,
      user: user
    } do
      # Test User → "TU"
      conn
      |> login(user)
      |> visit("/profile")
      |> assert_has("aside.sidebar .sb-user .avatar", text: "TU")
      |> refute_has("aside.sidebar .sb-user img.avatar")
    end

    test "sidebar shows the uploaded image when the user has a profile picture",
         %{conn: conn, user: user} do
      Huddlz.Accounts.create_profile_picture!(
        %{
          filename: "avatar.jpg",
          content_type: "image/jpeg",
          size_bytes: 1000,
          storage_path: "/uploads/profile_pictures/#{user.id}/avatar.jpg",
          thumbnail_path: "/uploads/profile_pictures/#{user.id}/avatar_thumb.jpg",
          user_id: user.id
        },
        actor: user
      )

      conn
      |> login(user)
      |> visit("/profile")
      |> assert_has("aside.sidebar .sb-user img.avatar[src*='_thumb.jpg']")
    end

    test "opens and cancels the styled profile picture removal dialog", %{
      conn: conn,
      user: user
    } do
      create_profile_picture(user)

      session =
        conn
        |> login(user)
        |> visit("/profile")
        |> refute_has("#remove-avatar-dialog")
        |> click_button("Remove")
        |> assert_has("#remove-avatar-dialog [role='dialog']")
        |> assert_has("#remove-avatar-dialog-title", text: "Remove your profile picture?")
        |> assert_has("#remove-avatar-dialog", text: "initials will appear instead")

      session
      |> within("#remove-avatar-dialog", fn session ->
        click_button(session, "Keep picture")
      end)
      |> refute_has("#remove-avatar-dialog")
      |> assert_has("main img.big-avatar[src*='_thumb.jpg']")
      |> assert_has("aside.sidebar .sb-user img.avatar[src*='_thumb.jpg']")
    end

    test "confirming profile picture removal updates profile and sidebar fallbacks", %{
      conn: conn,
      user: user
    } do
      create_profile_picture(user)

      conn
      |> login(user)
      |> visit("/profile")
      |> click_button("Remove")
      |> within("#remove-avatar-dialog", fn session ->
        click_button(session, "Remove picture")
      end)
      |> refute_has("#remove-avatar-dialog")
      |> assert_has("*", text: "Profile picture removed")
      |> refute_has("main img.big-avatar")
      |> assert_has("main .big-avatar", text: "TU")
      |> refute_has("aside.sidebar .sb-user img.avatar")
      |> assert_has("aside.sidebar .sb-user .avatar", text: "TU")
    end

    test "displays user profile when authenticated", %{conn: conn, user: user} do
      conn
      |> login(user)
      |> visit("/profile")
      |> assert_has("h1", text: "Profile")
      |> assert_has(".panel-head h2", text: "Account information")
      |> assert_has("*", text: to_string(user.email))
    end

    test "shows the profile form", %{conn: conn, user: user} do
      conn
      |> login(user)
      |> visit("/profile")
      |> assert_has("form")
      |> assert_has("input[name=\"form[display_name]\"]")
      |> assert_has("button[type=\"submit\"]", text: "Save changes")
    end

    test "updates display name successfully", %{conn: conn, user: user} do
      new_name = "Updated Test Name"

      conn
      |> login(user)
      |> visit("/profile")
      |> fill_in("Display name", with: new_name)
      |> click_button("Save changes")
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
      |> fill_in("Display name", with: "")
      |> click_button("Save changes")
      |> assert_has("*", text: "Failed to update display name")

      # Test too long (> 30 chars)
      long_name = String.duplicate("a", 31)

      session
      |> fill_in("Display name", with: long_name)
      |> click_button("Save changes")
      |> assert_has("*", text: "Failed to update display name")

      # Test single character (should be allowed)
      session
      |> fill_in("Display name", with: "A")
      |> click_button("Save changes")
      |> assert_has("*", text: "Display name updated successfully")
    end

    test "display name validation on change", %{conn: conn, user: user} do
      conn
      |> login(user)
      |> visit("/profile")
      |> fill_in("Display name", with: "")
      |> assert_has("form")
    end
  end

  describe "Email change" do
    setup do
      user =
        generate(
          user_with_password(
            email: "profile-email-#{System.unique_integer([:positive])}@example.com",
            display_name: "Email Change User",
            password: "OldPassword123!"
          )
        )

      %{user: user}
    end

    test "changes the signed-in identity and sends both security notices", %{
      conn: conn,
      user: user
    } do
      new_email = "changed-#{System.unique_integer([:positive])}@example.com"

      session =
        conn
        |> login(user)
        |> visit("/profile")
        |> assert_has("#email-change-form")
        |> fill_in("New email", with: new_email)
        |> fill_in("Confirm current password", with: "OldPassword123!")
        |> click_button("#change-email-button", "Change email")
        |> assert_has("*", text: "Email updated successfully")
        |> assert_has("aside.sidebar .sb-user", text: new_email)

      session
      |> visit("/profile/notifications")
      |> assert_has("aside.sidebar .sb-user", text: new_email)
      |> visit("/profile")
      |> refute_has("#email_change_current_password[value='OldPassword123!']")

      assert User |> Ash.get!(user.id, authorize?: false) |> Map.fetch!(:email) |> to_string() ==
               new_email

      enqueued =
        all_enqueued(worker: DeliverWorker)
        |> Enum.filter(&(&1.args["trigger"] == "email_changed"))

      assert enqueued |> Enum.map(& &1.args["payload"]["audience"]) |> Enum.sort() ==
               ["new", "old"]
    end

    test "shows a field error for an invalid email and clears the submitted password", %{
      conn: conn,
      user: user
    } do
      session =
        conn
        |> login(user)
        |> visit("/profile")
        |> fill_in("New email", with: "not-an-email")
        |> fill_in("Confirm current password", with: "OldPassword123!")
        |> click_button("#change-email-button", "Change email")

      session
      |> assert_has("#email_change_email[aria-invalid='true']")
      |> assert_has("#email_change_email-error-0", text: "Enter a valid email address.")
      |> refute_has("#email_change_current_password[value='OldPassword123!']")

      assert User |> Ash.get!(user.id, authorize?: false) |> Map.fetch!(:email) == user.email
    end

    test "rejects the current email as the new email", %{conn: conn, user: user} do
      conn
      |> login(user)
      |> visit("/profile")
      |> fill_in("New email", with: to_string(user.email))
      |> fill_in("Confirm current password", with: "OldPassword123!")
      |> click_button("#change-email-button", "Change email")
      |> assert_has("#email_change_email-error-0", text: "Enter a different email address.")

      refute_enqueued(worker: DeliverWorker, args: %{"trigger" => "email_changed"})
    end

    test "shows a field error when the new email is already used", %{conn: conn, user: user} do
      taken_email = "taken-#{System.unique_integer([:positive])}@example.com"
      _other_user = create_user(%{email: taken_email})

      conn
      |> login(user)
      |> visit("/profile")
      |> fill_in("New email", with: taken_email)
      |> fill_in("Confirm current password", with: "OldPassword123!")
      |> click_button("#change-email-button", "Change email")
      |> assert_has("#email_change_email-error-0", text: "That email is already in use.")

      assert User |> Ash.get!(user.id, authorize?: false) |> Map.fetch!(:email) == user.email
    end

    test "wrong current password leaves the identity unchanged and clears the password", %{
      conn: conn,
      user: user
    } do
      session =
        conn
        |> login(user)
        |> visit("/profile")
        |> fill_in(
          "New email",
          with: "wrong-password-#{System.unique_integer([:positive])}@example.com"
        )
        |> fill_in("Confirm current password", with: "WrongPassword")
        |> click_button("#change-email-button", "Change email")
        |> assert_has("*", text: "Email could not be updated")
        |> refute_has("#email_change_current_password[value='WrongPassword']")

      assert User |> Ash.get!(user.id, authorize?: false) |> Map.fetch!(:email) == user.email
      refute_enqueued(worker: DeliverWorker, args: %{"trigger" => "email_changed"})

      session
      |> fill_in("Confirm current password", with: "OldPassword123!")
      |> click_button("#change-email-button", "Change email")
      |> assert_has("*", text: "Email updated successfully")
      |> refute_has("*", text: "Email could not be updated")
    end
  end

  describe "Home location" do
    test "shows home location section", %{conn: conn, user: user} do
      conn
      |> login(user)
      |> visit("/profile")
      |> assert_has(".panel-head h2", text: "Home location")
      |> assert_has("#profile-location")
    end

    test "shows suggestions when typing", %{conn: conn, user: user} do
      # Profile's autocomplete uses place_id "p1" for Saint Augustine
      stub_places_autocomplete(%{
        "saint" => [%{known_places().saint_augustine | place_id: "p1"}]
      })

      session = conn |> login(user) |> visit("/profile")
      view = session.view

      view
      |> element("#profile-location-input")
      |> render_change(%{"profile-location_search" => "saint"})

      render_async(view)

      assert has_element?(view, "[role='option']", "Saint Augustine")
    end

    test "selecting a suggestion saves location", %{conn: conn, user: user} do
      stub_places_autocomplete(%{
        "saint" => [%{known_places().saint_augustine | place_id: "p1"}]
      })

      stub_place_details(%{"p1" => %{latitude: 29.89, longitude: -81.31}})

      session = conn |> login(user) |> visit("/profile")
      view = session.view

      view
      |> element("#profile-location-input")
      |> render_change(%{"profile-location_search" => "saint"})

      render_async(view)

      view |> element("[role='option']", "Saint Augustine") |> render_click()
      render_async(view)

      assert render(view) =~ "Home location updated"
    end

    test "handles autocomplete API errors", %{conn: conn, user: user} do
      stub_places_autocomplete_error({:request_failed, :timeout})

      session = conn |> login(user) |> visit("/profile")
      view = session.view

      view
      |> element("#profile-location-input")
      |> render_change(%{"profile-location_search" => "austin"})

      render_async(view)

      assert has_element?(view, "p", "Location search is currently unavailable")
    end

    test "clears error when user types in location field", %{conn: conn, user: user} do
      stub_places_autocomplete_error({:request_failed, :timeout})

      session = conn |> login(user) |> visit("/profile")
      view = session.view

      view
      |> element("#profile-location-input")
      |> render_change(%{"profile-location_search" => "bad location"})

      render_async(view)

      assert has_element?(view, "p", "Location search is currently unavailable")

      # Stub returns ok now — typing clears the error
      stub_places_autocomplete(%{})

      view
      |> element("#profile-location-input")
      |> render_change(%{"profile-location_search" => "trying again"})

      render_async(view)

      refute has_element?(view, "p", "Location search is currently unavailable")
    end
  end

  defp create_profile_picture(user) do
    Huddlz.Accounts.create_profile_picture!(
      %{
        filename: "avatar.jpg",
        content_type: "image/jpeg",
        size_bytes: 1000,
        storage_path: "/uploads/profile_pictures/#{user.id}/avatar.jpg",
        thumbnail_path: "/uploads/profile_pictures/#{user.id}/avatar_thumb.jpg",
        user_id: user.id
      },
      actor: user
    )
  end
end
