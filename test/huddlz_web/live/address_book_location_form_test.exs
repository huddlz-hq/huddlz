defmodule HuddlzWeb.Live.AddressBookLocationFormTest do
  use HuddlzWeb.ConnCase, async: true

  import Huddlz.Test.Helpers.LocationSelection
  import Phoenix.LiveViewTest

  for entry_point <- [:address_book, :new_huddl, :edit_huddl] do
    @entry_point entry_point

    describe "#{entry_point} address creation" do
      setup %{conn: conn} do
        owner = generate(user(role: :user))
        group = generate(group(is_public: true, owner_id: owner.id, actor: owner))
        path = creation_path(@entry_point, group, owner)
        {:ok, view, _} = conn |> login(owner) |> live(path)
        locations = Huddlz.Communities.list_group_locations!(group.id, actor: owner)
        %{view: view, owner: owner, group: group, path: path, locations: locations}
      end

      test "a failed save retains the final values and permits correction", %{
        view: view,
        owner: owner,
        group: group,
        locations: locations
      } do
        select_address(view)
        invalid_unit = String.duplicate("x", 101)

        view
        |> form("#new-location-form", %{
          "location_name" => "Final name",
          "location_unit" => invalid_unit
        })
        |> render_submit()

        assert has_element?(view, "#flash-error", "Failed to save location")
        assert has_element?(view, "#location-name-input[value='Final name']")
        assert has_element?(view, "#location-unit-input[value='#{invalid_unit}']")
        assert has_element?(view, "[data-testid=location-display]", "123 Main St")
        assert Huddlz.Communities.list_group_locations!(group.id, actor: owner) == locations

        view
        |> form("#new-location-form", %{"location_unit" => "4B"})
        |> render_submit()

        refute has_element?(view, "#new-location-form")
        saved = Huddlz.Communities.list_group_locations!(group.id, actor: owner)
        assert length(saved) == length(locations) + 1
        location = Enum.find(saved, &(&1.name == "Final name"))
        assert location.name == "Final name"
        assert location.unit == "4B"
      end

      test "clearing and reopening both start with empty address details", %{
        view: view,
        owner: owner,
        group: group,
        path: path,
        locations: locations
      } do
        select_address(view)
        view |> form("#new-location-form", %{"location_unit" => "4B"}) |> render_change()
        view |> element("#modal-address-autocomplete button", "Clear") |> render_click()

        assert_empty_form(view)
        select_address(view)
        view |> form("#new-location-form", %{"location_unit" => "711"}) |> render_change()
        view |> element("#new-location-form a", "Cancel") |> render_click()
        refute has_element?(view, "#new-location-form")
        render_patch(view, path)

        assert_empty_form(view)
        assert Huddlz.Communities.list_group_locations!(group.id, actor: owner) == locations
      end
    end
  end

  defp select_address(view) do
    select_location(view,
      id: "modal-address-autocomplete",
      display_text: "123 Main St",
      main_text: "Meeting place"
    )
  end

  defp assert_empty_form(view) do
    assert has_element?(view, "#location-name-input[value='']")
    assert has_element?(view, "#location-unit-input[value='']")
    assert has_element?(view, "#new-location-form button[type=submit][disabled]")
    assert has_element?(view, "#modal-address-autocomplete-input")
  end

  defp creation_path(:address_book, group, _owner),
    do: ~p"/groups/#{group.slug}/locations/new"

  defp creation_path(:new_huddl, group, _owner),
    do: ~p"/groups/#{group.slug}/huddlz/new/locations/new"

  defp creation_path(:edit_huddl, group, owner) do
    huddl = generate(huddl(group_id: group.id, creator_id: owner.id, actor: owner))
    ~p"/groups/#{group.slug}/huddlz/#{huddl.id}/edit/locations/new"
  end
end
