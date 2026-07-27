defmodule HuddlzWeb.NotificationsLiveTest do
  use HuddlzWeb.ConnCase, async: false

  import Phoenix.LiveViewTest,
    only: [element: 2, has_element?: 2, has_element?: 3, live: 2, render_click: 1]

  alias Huddlz.Notifications

  setup do
    user = generate(user(role: :user, confirmed_at: DateTime.utc_now()))
    %{user: user}
  end

  defp deliver!(user, trigger, payload) do
    {:ok, _job} = Notifications.deliver(user, trigger, payload)
    :ok
  end

  defp seed_notification(user, trigger, payload) do
    deliver!(user, trigger, payload)
    {:ok, %{results: [n | _]}} = Notifications.list_for_user(actor: user, page: [limit: 100])
    n
  end

  defp rsvp_payload(group_slug \\ "phoenix-elixir") do
    %{
      "huddl_id" => "00000000-0000-0000-0000-000000000000",
      "huddl_title" => "Boat Drinks",
      "group_slug" => group_slug,
      "starts_at_iso" => "2026-05-09T18:00:00Z"
    }
  end

  describe "anonymous access" do
    test "redirects to sign-in", %{conn: conn} do
      conn
      |> visit("/notifications")
      |> assert_path("/sign-in")
    end
  end

  describe "page chrome" do
    test "renders v3 shell with the bell active and Inbox chip default", %{conn: conn, user: user} do
      conn
      |> login(user)
      |> visit("/notifications")
      |> assert_has("h1", text: "Notifications")
      |> assert_has("aside.sidebar")
      |> assert_has(".icon-pill.active")
      |> assert_has(".filters .chip.is-active", text: "Inbox")
    end

    test "shows two filter chips with counts", %{conn: conn, user: user} do
      conn
      |> login(user)
      |> visit("/notifications")
      |> assert_has(".filters .chip", text: "Inbox")
      |> assert_has(".filters .chip", text: "Invites")
    end
  end

  describe "Inbox filter (default)" do
    test "lists the actor's notifications", %{conn: conn, user: user} do
      deliver!(user, :password_changed, %{})

      conn
      |> login(user)
      |> visit("/notifications")
      |> assert_has(".notif-row .row-title", text: "Password changed")
    end

    test "Inbox count reflects only unread notifications", %{conn: conn, user: user} do
      deliver!(user, :password_changed, %{})
      deliver!(user, :email_changed, %{"old_email" => "a@b.com"})

      read_one = seed_notification(user, :account_role_changed, %{})
      {:ok, _} = Notifications.mark_read(read_one, actor: user)

      conn
      |> login(user)
      |> visit("/notifications")
      |> assert_has(".filters .chip", text: "Inbox · 2 unread")
    end

    test "empty state copy", %{conn: conn, user: user} do
      conn
      |> login(user)
      |> visit("/notifications")
      |> assert_has("p",
        text:
          "No notifications yet. Reminders and group activity will appear here as they happen."
      )
    end

    test "Mark all as read button is hidden when there are no unread", %{conn: conn, user: user} do
      conn
      |> login(user)
      |> visit("/notifications")
      |> refute_has("button", text: "Mark all as read")
    end

    test "Mark all as read shows when unread > 0 and clears the count when clicked", %{
      conn: conn,
      user: user
    } do
      deliver!(user, :password_changed, %{})

      conn
      |> login(user)
      |> visit("/notifications")
      |> assert_has(".filters .chip", text: "Inbox · 1 unread")
      |> click_button("Mark all as read")
      |> assert_has(".filters .chip", text: "Inbox · 0 unread")
    end

    test "Mark all as read clears unread beyond the visible page", %{conn: conn, user: user} do
      # 25 unread > 20-per-page. Per-page iteration would leave 5 unread;
      # bulk update clears all of them.
      for _ <- 1..25, do: deliver!(user, :password_changed, %{})

      conn
      |> login(user)
      |> visit("/notifications")
      |> assert_has(".filters .chip", text: "Inbox · 25 unread")
      |> click_button("Mark all as read")
      |> assert_has(".filters .chip", text: "Inbox · 0 unread")
    end
  end

  describe "Invites filter" do
    test "lists only notifications that need a response", %{conn: conn, user: user} do
      deliver!(user, :password_changed, %{})

      deliver!(user, :group_member_added, %{
        "group_slug" => "phoenix-elixir",
        "group_name" => "Phoenix Elixir"
      })

      conn
      |> login(user)
      |> visit("/notifications?filter=invites")
      |> assert_has(".filters .chip.is-active", text: "Invites")
      |> assert_has(".notif-row .row-title", text: "Added to Phoenix Elixir")
      |> refute_has(".notif-row .row-title", text: "Password changed")
    end

    test "Invites count reflects unread invite-shaped notifications", %{conn: conn, user: user} do
      deliver!(user, :group_member_added, %{
        "group_slug" => "g1",
        "group_name" => "G1"
      })

      deliver!(user, :group_member_added, %{
        "group_slug" => "g2",
        "group_name" => "G2"
      })

      conn
      |> login(user)
      |> visit("/notifications")
      |> assert_has(".filters .chip", text: "Invites · 2")
    end

    test "empty state copy", %{conn: conn, user: user} do
      conn
      |> login(user)
      |> visit("/notifications?filter=invites")
      |> assert_has("p",
        text:
          "No invites right now. When organizers invite you to a huddl or group, they'll show up here."
      )
    end
  end

  describe "URL filtering" do
    test "unknown filter falls back to Inbox", %{conn: conn, user: user} do
      conn
      |> login(user)
      |> visit("/notifications?filter=garbage")
      |> assert_has(".filters .chip.is-active", text: "Inbox")
    end
  end

  describe "scoping" do
    test "does not leak other users' notifications", %{conn: conn, user: user} do
      stranger = generate(user(role: :user, confirmed_at: DateTime.utc_now()))
      deliver!(stranger, :password_changed, %{})

      conn
      |> login(user)
      |> visit("/notifications")
      |> refute_has(".notif-row .row-title", text: "Password changed")
      |> assert_has("p",
        text:
          "No notifications yet. Reminders and group activity will appear here as they happen."
      )
    end
  end

  describe "row destinations" do
    test "rows with a source_url render an Open link", %{conn: conn, user: user} do
      deliver!(user, :rsvp_confirmation, rsvp_payload())

      conn
      |> login(user)
      |> visit("/notifications")
      |> assert_has(
        ~s|.notif-row a.pill[href="/groups/phoenix-elixir/huddlz/00000000-0000-0000-0000-000000000000"]|,
        text: "Open"
      )
    end

    test "linked and unlinked unread rows offer a separate Mark read action", %{
      conn: conn,
      user: user
    } do
      linked =
        seed_notification(user, :rsvp_confirmation, rsvp_payload())

      unlinked = seed_notification(user, :group_member_removed, %{"group_name" => "Old Club"})

      conn
      |> login(user)
      |> visit("/notifications")
      |> assert_has("#notification-actions-#{linked.id} a", text: "Open")
      |> assert_has("#mark-notification-read-#{linked.id}", text: "Mark read")
      |> assert_has("#mark-notification-read-#{unlinked.id}", text: "Mark read")
      |> refute_has("#notification-actions-#{unlinked.id} a", text: "Open")
    end

    test "marking a linked notification read updates its row and unread count in place", %{
      conn: conn,
      user: user
    } do
      notification =
        seed_notification(user, :rsvp_confirmation, rsvp_payload("missing-group"))

      untouched = seed_notification(user, :password_changed, %{})
      {:ok, view, _html} = conn |> login(user) |> live("/notifications")

      assert has_element?(view, ".filters .chip", "Inbox · 2 unread")

      view
      |> element("#mark-notification-read-#{notification.id}")
      |> render_click()

      assert has_element?(view, ".filters .chip", "Inbox · 1 unread")
      assert has_element?(view, "#notification-#{notification.id}")
      assert has_element?(view, "#notification-actions-#{notification.id} a", "Open")
      refute has_element?(view, "#mark-notification-read-#{notification.id}")
      assert has_element?(view, "#mark-notification-read-#{untouched.id}", "Mark read")
    end

    test "a read waitlist promotion remains visible in Invites", %{conn: conn, user: user} do
      notification =
        seed_notification(user, :waitlist_promoted, %{
          "huddl_id" => "00000000-0000-0000-0000-000000000000",
          "huddl_title" => "Elixir Picnic",
          "group_slug" => "elixir-picnic",
          "starts_at_iso" => "2026-08-01T16:00:00Z"
        })

      conn = login(conn, user)
      {:ok, view, _html} = live(conn, "/notifications?filter=invites")

      view
      |> element("#mark-notification-read-#{notification.id}")
      |> render_click()

      assert has_element?(view, ".filters .chip", "Inbox · 0 unread")

      assert has_element?(
               view,
               "#notification-#{notification.id}",
               "Waitlist promoted: Elixir Picnic"
             )

      assert has_element?(view, "#notification-actions-#{notification.id} a", "Open")
      refute has_element?(view, "#mark-notification-read-#{notification.id}")

      {:ok, reloaded_view, _html} = live(conn, "/notifications?filter=invites")

      assert has_element?(
               reloaded_view,
               "#notification-#{notification.id}",
               "Waitlist promoted: Elixir Picnic"
             )

      refute has_element?(reloaded_view, "#mark-notification-read-#{notification.id}")
    end

    test "Open and Mark read have distinct accessible names", %{conn: conn, user: user} do
      notification =
        seed_notification(user, :rsvp_confirmation, rsvp_payload())

      conn
      |> login(user)
      |> visit("/notifications")
      |> assert_has(
        "#notification-actions-#{notification.id} a[aria-label=\"Open RSVP confirmed: Boat Drinks\"]"
      )
      |> assert_has(
        "#mark-notification-read-#{notification.id}[aria-label=\"Mark RSVP confirmed: Boat Drinks as read\"]"
      )
    end
  end

  describe "pagination" do
    setup %{user: user} do
      # 22 notifications → 2 pages of 20
      for i <- 1..22 do
        deliver!(user, :password_changed, %{"i" => i})
        # tiny stagger so inserted_at order is stable
        Process.sleep(2)
      end

      :ok
    end

    test "shows pagination when more than 20 results", %{conn: conn, user: user} do
      conn
      |> login(user)
      |> visit("/notifications")
      |> assert_has(".filters .chip", text: "Inbox · 22 unread")
      |> assert_has(".pagination .page-num", text: "2")
    end

    test "page=2 shows the remaining 2", %{conn: conn, user: user} do
      conn
      |> login(user)
      |> visit("/notifications?page=2")
      |> assert_has(".notif-row")
    end

    test "out-of-range ?page= clamps to last valid page", %{conn: conn, user: user} do
      conn
      |> login(user)
      |> visit("/notifications?page=999")
      |> assert_path("/notifications", query_params: %{"page" => "2"})
    end
  end
end
