defmodule HuddlzWeb.HuddlLive.NewLocationTest do
  @moduledoc """
  Tests for the "Add new address" modal in the huddl creation form.
  """
  use HuddlzWeb.ConnCase, async: true

  import Huddlz.Generator
  import Phoenix.LiveViewTest

  describe "add new address modal from huddl form" do
    setup do
      owner = generate(user(role: :user))
      group = generate(group(is_public: true, owner_id: owner.id, actor: owner))
      %{owner: owner, group: group}
    end

    test "modal renders at the correct route", %{conn: conn, owner: owner, group: group} do
      {:ok, view, _html} =
        conn
        |> login(owner)
        |> live(~p"/groups/#{group.slug}/huddlz/new/locations/new")

      assert has_element?(view, "#new-location-modal")
      assert has_element?(view, "h2", "Add New Address")
    end

    test "modal contains autocomplete inside a form", %{
      conn: conn,
      owner: owner,
      group: group
    } do
      {:ok, view, _html} =
        conn
        |> login(owner)
        |> live(~p"/groups/#{group.slug}/huddlz/new/locations/new")

      # The autocomplete input must be inside a form — this is what was broken
      html = render(view)
      assert html =~ ~s(data-testid="location-input")
      assert html =~ ~s(phx-submit="save_location")
    end

    test "save button is disabled until a location is selected", %{
      conn: conn,
      owner: owner,
      group: group
    } do
      {:ok, view, _html} =
        conn
        |> login(owner)
        |> live(~p"/groups/#{group.slug}/huddlz/new/locations/new")

      # Save button should be disabled initially
      assert has_element?(view, "button[disabled]", "Save Address")
    end

    test "selecting an address enables save and pre-populates name", %{
      conn: conn,
      owner: owner,
      group: group
    } do
      {:ok, view, _html} =
        conn
        |> login(owner)
        |> live(~p"/groups/#{group.slug}/huddlz/new/locations/new")

      # Simulate LocationAutocomplete selecting a place
      send(
        view.pid,
        {:location_selected, "modal-address-autocomplete",
         %{
           place_id: "ChIJ_test",
           display_text: "500 E Cesar Chavez St, Austin, TX",
           main_text: "Austin Convention Center",
           latitude: 30.263,
           longitude: -97.739
         }}
      )

      html = render(view)

      # Name should be pre-populated from main_text
      assert html =~ "Austin Convention Center"

      # Save button should no longer be disabled
      refute has_element?(view, "button[disabled]", "Save Address")
    end

    test "saving creates location and returns to huddl form", %{
      conn: conn,
      owner: owner,
      group: group
    } do
      {:ok, view, _html} =
        conn
        |> login(owner)
        |> live(~p"/groups/#{group.slug}/huddlz/new/locations/new")

      # Simulate selecting an address
      send(
        view.pid,
        {:location_selected, "modal-address-autocomplete",
         %{
           place_id: "ChIJ_test",
           display_text: "500 E Cesar Chavez St, Austin, TX",
           main_text: "Convention Center",
           latitude: 30.263,
           longitude: -97.739
         }}
      )

      render(view)

      # Submit the form
      view
      |> element("form[phx-submit='save_location']")
      |> render_submit()

      # Should patch back to the huddl form (not redirect)
      assert_patched(view, ~p"/groups/#{group.slug}/huddlz/new")

      # Verify the location was actually created
      {:ok, locations} =
        Huddlz.Communities.list_group_locations(group.id, actor: owner)

      assert length(locations) == 1
      assert hd(locations).name == "Convention Center"
      assert hd(locations).address == "500 E Cesar Chavez St, Austin, TX"
    end

    test "cancel returns to huddl form without creating a location", %{
      conn: conn,
      owner: owner,
      group: group
    } do
      {:ok, view, _html} =
        conn
        |> login(owner)
        |> live(~p"/groups/#{group.slug}/huddlz/new/locations/new")

      # Click the modal's cancel link (use the one inside the modal form)
      view
      |> element("#new-location-modal a", "Cancel")
      |> render_click()

      assert_patched(view, ~p"/groups/#{group.slug}/huddlz/new")

      # No locations should have been created
      {:ok, locations} =
        Huddlz.Communities.list_group_locations(group.id, actor: owner)

      assert locations == []
    end
  end
end
