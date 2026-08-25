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

    test "does not re-populate a preference the user deliberately cleared", %{conn: conn} do
      user = generate(user())

      # First visit auto-populates and stamps the "already asked" marker.
      {:ok, _view, _html} =
        conn
        |> login(user)
        |> put_connect_params(%{"timezone" => "America/Denver"})
        |> live(~p"/my-huddlz")

      populated = Ash.get!(Huddlz.Accounts.User, user.id, authorize?: false)
      assert populated.time_zone_preference == "America/Denver"
      assert populated.time_zone_preference_set_at

      # The user then chooses "Use each huddl's own time zone", clearing it.
      {:ok, cleared} =
        populated
        |> Ash.Changeset.for_update(
          :update_display_timezone,
          %{time_zone_preference: nil},
          actor: populated
        )
        |> Ash.update()

      assert cleared.time_zone_preference == nil

      # A later mount with fresh connect params must leave it cleared.
      {:ok, _view, _html} =
        conn
        |> login(cleared)
        |> put_connect_params(%{"timezone" => "America/Denver"})
        |> live(~p"/my-huddlz")

      reloaded = Ash.get!(Huddlz.Accounts.User, user.id, authorize?: false)
      assert reloaded.time_zone_preference == nil
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
