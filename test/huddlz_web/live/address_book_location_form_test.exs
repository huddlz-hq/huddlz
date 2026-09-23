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
        invalid_address = String.duplicate("x", 501)

        view
        |> form("#new-location-form", %{
          "location_name" => "Final name",
          "location_address" => invalid_address
        })
        |> render_submit()

        assert has_element?(view, "#flash-error", "Failed to save location")
        assert has_element?(view, "#location-name-input[value='Final name']")
        assert has_element?(view, "#location-address-input", invalid_address)
        assert has_element?(view, "[data-testid=location-display]", "123 Main St")
        assert Huddlz.Communities.list_group_locations!(group.id, actor: owner) == locations

        view
        |> form("#new-location-form", %{"location_address" => "Suite 4B, 123 Main St"})
        |> render_submit()

        refute has_element?(view, "#new-location-form")
        saved = Huddlz.Communities.list_group_locations!(group.id, actor: owner)
        assert length(saved) == length(locations) + 1
        location = Enum.find(saved, &(&1.name == "Final name"))
        assert location.name == "Final name"
        assert location.address == "Suite 4B, 123 Main St"
      end

      test "clearing and reopening both start with empty address details", %{
        view: view,
        owner: owner,
        group: group,
        path: path,
        locations: locations
      } do
        select_address(view)
        view |> form("#new-location-form", %{"location_address" => "Suite 4B"}) |> render_change()
        view |> element("#modal-address-autocomplete button", "Clear") |> render_click()

        assert_empty_form(view)
        select_address(view)

        view
        |> form("#new-location-form", %{"location_address" => "Suite 711"})
        |> render_change()

        view |> element("#new-location-form a", "Cancel") |> render_click()
        refute has_element?(view, "#new-location-form")
        render_patch(view, path)

        assert_empty_form(view)
        assert Huddlz.Communities.list_group_locations!(group.id, actor: owner) == locations
      end

      test "a browser's line breaks neither count as an edit nor get saved", %{
        view: view,
        owner: owner,
        group: group
      } do
        select_location(view,
          id: "modal-address-autocomplete",
          display_text: "Alfred's, 222 W King St",
          main_text: "Alfred's",
          formatted_address: "222 W King St, St. Augustine, FL 32084, USA",
          types: ["bar", "establishment"]
        )

        view
        |> form("#new-location-form", %{
          "location_address" => "Alfred's\r\n222 W King St, St. Augustine, FL 32084, USA"
        })
        |> render_change()

        view |> element("#modal-address-autocomplete button", "Change location") |> render_click()

        select_location(view,
          id: "modal-address-autocomplete",
          display_text: "Odd Birds, 10 Anastasia Blvd",
          main_text: "Odd Birds",
          formatted_address: "10 Anastasia Blvd, St. Augustine, FL 32080, USA",
          types: ["bar", "establishment"]
        )

        refute has_element?(view, "button", "Keep my address")

        view |> form("#new-location-form", %{"location_name" => "Odd Birds"}) |> render_submit()

        saved = Huddlz.Communities.list_group_locations!(group.id, actor: owner)
        location = Enum.find(saved, &(&1.name == "Odd Birds"))
        assert location.address == "Odd Birds\n10 Anastasia Blvd, St. Augustine, FL 32080, USA"
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
    refute has_element?(view, "#location-address-input", ~r/\S/)
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
