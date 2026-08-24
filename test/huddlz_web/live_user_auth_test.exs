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
  end
end
