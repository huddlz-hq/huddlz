defmodule HuddlzWeb.UnsubscribeControllerTest do
  use HuddlzWeb.ConnCase, async: true

  @moduletag :unsubscribe

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

    test "renders inside the v3 auth-shell layout", %{conn: conn} do
      user = generate(user())
      token = Notifications.unsubscribe_token(user, :rsvp_received)

      session = visit(conn, "/unsubscribe/#{token}")

      # v3 chromeless wrapper — brand topbar + auth-frame container.
      assert_has(session, ".auth-topbar a[href='/']")
      assert_has(session, ".auth-frame h1", text: "Confirm unsubscribe")
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

  describe "impersonation attribution" do
    setup do
      admin = generate(user(role: :admin))
      target = generate(user())
      conn = build_conn() |> login(admin) |> post(~p"/admin/impersonations/#{target.id}")
      %{impersonating: conn, admin: admin, target: target}
    end

    test "confirmation records the target, administrator, and impersonation", ctx do
      token = Notifications.unsubscribe_token(ctx.target, :rsvp_received)
      id = get_session(ctx.impersonating, :impersonation_id)

      ctx.impersonating
      |> recycle()
      |> visit("/unsubscribe/#{token}")
      |> assert_has("button", text: "Stop viewing as #{ctx.target.display_name}")
      |> click_button("Unsubscribe")

      assert reloaded_user(ctx.target).notification_preferences["rsvp_received"] == false

      row =
        User.Version
        |> Ash.Query.filter(
          version_source_id == ^ctx.target.id and
            version_action_name == :update_notification_preferences
        )
        |> Ash.read_one!(authorize?: false)

      assert row.actor_id == ctx.target.id
      assert row.impersonator_id == ctx.admin.id
      assert row.impersonation_id == id
    end

    test "a different recipient's link cannot change their preferences while impersonating",
         ctx do
      recipient = generate(user())
      token = Notifications.unsubscribe_token(recipient, :rsvp_received)

      ctx.impersonating
      |> recycle()
      |> visit("/unsubscribe/#{token}")
      |> assert_has("button", text: "Stop viewing as #{ctx.target.display_name}")
      |> click_button("Unsubscribe")
      |> assert_has("*",
        text: "This unsubscribe link belongs to someone else. Stop impersonation before using it."
      )

      refute reloaded_user(recipient).notification_preferences["rsvp_received"] == false
      refute reloaded_user(ctx.target).notification_preferences["rsvp_received"] == false
    end

    test "the unsubscribe page can restore the administrator's session", ctx do
      token = Notifications.unsubscribe_token(ctx.target, :rsvp_received)

      ctx.impersonating
      |> recycle()
      |> visit("/unsubscribe/#{token}")
      |> click_button("Stop viewing as #{ctx.target.display_name}")
      |> assert_path("/admin/users")
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
