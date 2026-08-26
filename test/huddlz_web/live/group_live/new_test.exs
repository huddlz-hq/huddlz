defmodule HuddlzWeb.GroupLive.NewTest do
  use HuddlzWeb.ConnCase, async: true

  import Huddlz.Test.Helpers.LocationSelection
  import Huddlz.Test.Helpers.TimeZoneSelection

  alias Huddlz.Communities.Group

  require Ash.Query

  describe "time zone on create" do
    test "the picker renders blank rather than pre-selected on the Etc/UTC default", %{conn: conn} do
      user = generate(user(role: :user))

      session =
        conn
        |> login(user)
        |> visit(~p"/groups/new")

      assert_has(session, "label", text: "Time zone")

      # Regression: binding the picker to the `:time_zone` attribute rendered
      # it pre-selected on the attribute's static "Etc/UTC" default (Ash
      # force-sets defaults into `changeset.attributes` before the form is
      # built), which then submitted back as an explicit pick and killed
      # geo-derivation. The `:time_zone_selection` argument has no default.
      refute session.conn.resp_body =~ ~s(<option selected value="Etc/UTC">)
      refute session.conn.resp_body =~ ~s(<option value="Etc/UTC" selected>)
    end

    test "geo-derives the time zone from the location picked in the real form", %{conn: conn} do
      # Austin, TX -> America/Chicago
      stub_geocode(%{latitude: 30.27, longitude: -97.74})
      user = generate(user(role: :user))

      session =
        conn
        |> login(user)
        |> visit(~p"/groups/new")
        |> fill_in("Group name", with: "Derived Zone Group")
        |> fill_in("Description", with: "A group whose time zone comes from its location.")

      select_location(session, id: "group-location", display_text: "Austin, TX, USA")

      click_button(session, "Create group")

      group =
        Group
        |> Ash.Query.filter(name == "Derived Zone Group")
        |> Ash.read_one!(authorize?: false)

      assert group.time_zone == "America/Chicago"
    end

    test "keeps an explicit pick from the real form", %{conn: conn} do
      stub_geocode(%{latitude: 30.27, longitude: -97.74})
      user = generate(user(role: :user))

      session =
        conn
        |> login(user)
        |> visit(~p"/groups/new")
        |> fill_in("Group name", with: "Explicit Zone Group")
        |> fill_in("Description", with: "A group whose organizer overrode the time zone.")

      session = select_time_zone(session, "America/Denver", id: "group-time-zone")

      select_location(session, id: "group-location", display_text: "Austin, TX, USA")

      click_button(session, "Create group")

      group =
        Group
        |> Ash.Query.filter(name == "Explicit Zone Group")
        |> Ash.read_one!(authorize?: false)

      assert group.time_zone == "America/Denver"
    end
  end
end
