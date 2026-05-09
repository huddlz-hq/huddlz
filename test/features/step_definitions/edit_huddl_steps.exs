defmodule EditHuddlSteps do
  @moduledoc """
  Cucumber step definitions for editing a huddl, with a focus on the
  saved-location flow and how location coordinates are persisted.
  """
  use Cucumber.StepDefinition

  import Huddlz.Generator
  import PhoenixTest
  import Phoenix.LiveViewTest

  alias Huddlz.Communities.Group

  require Ash.Query

  step "the group {string} has a saved location {string} at {string} with coordinates {float}, {float}",
       %{args: [group_name, name, address, lat, lng]} = context do
    group = lookup_group(group_name)
    owner = Enum.find(context.users, &(&1.id == group.owner_id))

    location =
      generate(
        group_location(
          group_id: group.id,
          name: name,
          address: address,
          latitude: lat,
          longitude: lng,
          actor: owner
        )
      )

    locations = Map.get(context, :group_locations, [])
    Map.put(context, :group_locations, [location | locations])
  end

  step "the group {string} has a huddl {string} at {string}",
       %{args: [group_name, title, address]} = context do
    group = lookup_group(group_name)
    owner = Enum.find(context.users, &(&1.id == group.owner_id))

    huddl =
      generate(
        huddl(
          group_id: group.id,
          creator_id: owner.id,
          title: title,
          physical_location: address,
          actor: owner
        )
      )

    Map.put(context, :current_huddl, huddl)
  end

  step "the saved location {string} should be preselected", %{args: [name]} = context do
    session = context[:session] || context[:conn]
    assert_has(session, "[data-testid='saved-location-display']", text: name)
    context
  end

  step "I switch the saved location to {string}", %{args: [name]} = context do
    session = context[:session] || context[:conn]
    location = lookup_saved_location(context, name)

    send(session.view.pid, {:saved_location_selected, "saved-location-picker", location})
    render(session.view)

    Map.merge(context, %{session: session, conn: session})
  end

  step "I edit the saved location selection", context do
    session = context[:session] || context[:conn]

    # Mirror clicking the (hover-revealed) edit pencil on the selected-location
    # card. This puts the picker into search mode so "Add new address" appears.
    session.view
    |> element("[data-testid='saved-location-selected'] [role='button']")
    |> render_click()

    Map.merge(context, %{session: session, conn: session})
  end

  step "I add a new saved address {string} with coordinates {float}, {float} via the modal",
       %{args: [address, lat, lng]} = context do
    session = context[:session] || context[:conn]

    # The "Add new address" link patches into the modal route on the same LV.
    session = click_link(session, "Add new address")

    # Simulate the LocationAutocomplete component selecting a place. The parent
    # huddl-edit LiveView captures the coords on its socket, ready for save.
    send(
      session.view.pid,
      {:location_selected, "modal-address-autocomplete",
       %{
         place_id: "p_test_#{System.unique_integer([:positive])}",
         display_text: address,
         main_text: address,
         latitude: lat,
         longitude: lng
       }}
    )

    render(session.view)

    session = click_button(session, "Save Address")

    Map.merge(context, %{session: session, conn: session})
  end

  defp lookup_group(name) do
    Group
    |> Ash.Query.filter(name == ^name)
    |> Ash.read_one!(authorize?: false)
  end

  defp lookup_saved_location(context, name) do
    locations = Map.get(context, :group_locations, [])

    Enum.find(locations, fn loc -> to_string(loc.name) == name end) ||
      raise "Saved location not found: #{name}"
  end
end
