defmodule HuddlzWeb.NotificationNavigationTest do
  use HuddlzWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Huddlz.Notifications

  setup do
    user = generate(user(role: :user, confirmed_at: DateTime.utc_now()))
    %{user: user}
  end

  test "signed-out navigation does not expose notification state", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/help")

    refute has_element?(view, "#notification-nav-link")
    refute has_element?(view, "#notification-nav-badge")
  end

  test "zero unread notifications renders no badge", %{conn: conn, user: user} do
    {:ok, view, _html} = live(login(conn, user), ~p"/help")

    assert has_element?(view, ~s|#notification-nav-link[aria-label="Notifications"]|)
    refute has_element?(view, "#notification-nav-badge")
  end

  test "one unread notification renders an accessible badge", %{conn: conn, user: user} do
    deliver!(user)

    {:ok, view, _html} = live(login(conn, user), ~p"/help")

    assert has_element?(
             view,
             ~s|#notification-nav-link[aria-label="Notifications, 1 unread"]|
           )

    assert has_element?(view, "#notification-nav-badge", "1")
  end

  test "large unread counts use a compact visual cap and retain the exact accessible count", %{
    conn: conn,
    user: user
  } do
    for _ <- 1..100, do: deliver!(user)

    {:ok, view, _html} = live(login(conn, user), ~p"/help")

    assert has_element?(
             view,
             ~s|#notification-nav-link[aria-label="Notifications, 100 unread"]|
           )

    assert has_element?(view, "#notification-nav-badge", "99+")
  end

  test "a new notification updates persistent navigation during an active session", %{
    conn: conn,
    user: user
  } do
    {:ok, view, _html} = live(login(conn, user), ~p"/help")
    refute has_element?(view, "#notification-nav-badge")

    deliver!(user)

    assert has_element?(view, "#notification-nav-badge", "1")
  end

  test "individual and bulk read actions update the badge without reloading", %{
    conn: conn,
    user: user
  } do
    deliver!(user, :group_archived, %{"group_name" => "Past group"})
    deliver!(user, :group_archived, %{"group_name" => "Other past group"})

    {:ok, %{results: [notification | _]}} =
      Notifications.list_for_user(actor: user, page: [limit: 10])

    {:ok, view, _html} = live(login(conn, user), ~p"/notifications")
    assert has_element?(view, "#notification-nav-badge", "2")

    view
    |> element("#notification-#{notification.id} button[phx-click=mark_read]")
    |> render_click()

    assert has_element?(view, "#notification-nav-badge", "1")

    view
    |> element(~s|button[phx-click="mark_all_read"]|)
    |> render_click()

    refute has_element?(view, "#notification-nav-badge")
  end

  defp deliver!(user) do
    assert {:ok, _job} = Notifications.deliver(user, :password_changed, %{})
  end

  defp deliver!(user, trigger, payload) do
    assert {:ok, _job} = Notifications.deliver(user, trigger, payload)
  end
end
