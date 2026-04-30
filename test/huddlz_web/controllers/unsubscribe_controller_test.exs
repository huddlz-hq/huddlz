defmodule HuddlzWeb.UnsubscribeControllerTest do
  use HuddlzWeb.ConnCase, async: true

  require Ash.Query

  alias Huddlz.Accounts.User
  alias Huddlz.Notifications

  describe "GET /unsubscribe/:token" do
    test "renders a confirmation page without changing preferences", %{conn: conn} do
      user = generate(user())
      token = Notifications.unsubscribe_token(user, :rsvp_received)

      session = visit(conn, "/unsubscribe/#{token}")

      assert_has(session, "h1", text: "Confirm unsubscribe")
      assert_has(session, "form#unsubscribe-confirmation-form")
      refute reloaded_user(user).notification_preferences["rsvp_received"] == false
    end

    test "renders inside the standard application layout", %{conn: conn} do
      user = generate(user())
      token = Notifications.unsubscribe_token(user, :rsvp_received)

      session = visit(conn, "/unsubscribe/#{token}")

      # Standard app layout shell — navbar brand and footer link
      assert_has(session, "header a", text: "huddlz")
      assert_has(session, "footer a", text: "Contribute on GitHub")
    end

    test "rejects unknown triggers without changing preferences", %{conn: conn} do
      user = generate(user())
      token = sign_token(user, :not_a_real_trigger)

      session = visit(conn, "/unsubscribe/#{token}")

      assert_has(session, "*", text: "This unsubscribe link is invalid or has expired.")
      refute reloaded_user(user).notification_preferences["not_a_real_trigger"] == false
    end
  end

  describe "POST /unsubscribe/:token" do
    test "opts the user out after confirmation", %{conn: conn} do
      user = generate(user())
      token = Notifications.unsubscribe_token(user, :rsvp_received)

      conn
      |> visit("/unsubscribe/#{token}")
      |> click_button("Unsubscribe")

      assert reloaded_user(user).notification_preferences["rsvp_received"] == false
    end

    test "is idempotent when the user is already opted out", %{conn: conn} do
      user = generate(user())
      token = Notifications.unsubscribe_token(user, :rsvp_received)

      conn
      |> visit("/unsubscribe/#{token}")
      |> click_button("Unsubscribe")

      conn
      |> visit("/unsubscribe/#{token}")
      |> click_button("Unsubscribe")
      |> assert_has("*", text: "Unsubscribed from")

      assert reloaded_user(user).notification_preferences["rsvp_received"] == false
    end
  end

  defp reloaded_user(user) do
    User
    |> Ash.Query.filter(id == ^user.id)
    |> Ash.read_one!(authorize?: false)
  end

  defp sign_token(user, trigger) do
    Phoenix.Token.sign(
      HuddlzWeb.Endpoint,
      "notifications:unsubscribe",
      {user.id, trigger}
    )
  end
end
