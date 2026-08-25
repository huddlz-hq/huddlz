defmodule HuddlzWeb.LiveUserAuthTest do
  use HuddlzWeb.ConnCase, async: true

  import Phoenix.LiveViewTest, only: [live: 2, put_connect_params: 2]

  describe ":app on_mount" do
    test "assigns browser_time_zone from the connect params", %{conn: conn} do
      user = generate(user())

      {:ok, view, _html} =
        conn
        |> login(user)
        |> put_connect_params(%{"timezone" => "America/Denver"})
        |> live(~p"/my-huddlz")

      assert :sys.get_state(view.pid).socket.assigns.browser_time_zone == "America/Denver"
    end

    test "assigns nil browser_time_zone when connect params carry none", %{conn: conn} do
      user = generate(user())

      {:ok, view, _html} = conn |> login(user) |> live(~p"/my-huddlz")

      assert :sys.get_state(view.pid).socket.assigns.browser_time_zone == nil
    end

    test "populates a nil time_zone_preference from the connect params on first visit", %{
      conn: conn
    } do
      user = generate(user())
      assert user.time_zone_preference == nil

      {:ok, _view, _html} =
        conn
        |> login(user)
        |> put_connect_params(%{"timezone" => "America/Denver"})
        |> live(~p"/my-huddlz")

      updated = Ash.get!(Huddlz.Accounts.User, user.id, authorize?: false)
      assert updated.time_zone_preference == "America/Denver"
    end

    test "does not override an existing time_zone_preference", %{conn: conn} do
      user = generate(user(time_zone_preference: "America/New_York"))

      {:ok, _view, _html} =
        conn
        |> login(user)
        |> put_connect_params(%{"timezone" => "America/Denver"})
        |> live(~p"/my-huddlz")

      updated = Ash.get!(Huddlz.Accounts.User, user.id, authorize?: false)
      assert updated.time_zone_preference == "America/New_York"
    end
  end
end
