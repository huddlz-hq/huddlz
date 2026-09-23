defmodule OrganizerAddressSteps do
  use Cucumber.StepDefinition

  import ExUnit.Assertions
  import Huddlz.Test.Helpers.LocationSelection
  import PhoenixTest

  @venue_types ["cafe", "establishment", "point_of_interest"]
  @street_types ["route"]

  step "I choose the place {string} with full address {string}",
       %{args: [display_text, full_address]} = context do
    choose_place(context, "Starbucks Coffee Company", display_text, full_address, [])
  end

  step "I choose the venue {string} at {string}", %{args: [venue, address]} = context do
    choose_place(context, venue, venue <> ", " <> address, address, @venue_types)
  end

  step "I choose the street {string} at {string}", %{args: [street, address]} = context do
    choose_place(context, street, street <> ", Jacksonville, FL, USA", address, @street_types)
  end

  step "I change the place to the venue {string} at {string}",
       %{args: [venue, address]} = context do
    session = click_button(context.session, "Change location…")
    context = Map.merge(context, %{session: session, conn: session})
    choose_place(context, venue, venue <> ", " <> address, address, @venue_types)
  end

  step "the address reads {string}", %{args: [expected]} = context do
    assert address_text(context.session) == expected
    context
  end

  step "the address reads {string} then {string}", %{args: [first, second]} = context do
    assert address_text(context.session) == first <> "\n" <> second
    context
  end

  step "I am asked whether to replace my address", context do
    assert_has(context.session, "button", text: "Use the new place's address")
    assert_has(context.session, "button", text: "Keep my address")
    context
  end

  step "I search the location picker for {string}", %{args: [text]} = context do
    context.session.view
    |> Phoenix.LiveViewTest.element("#saved-location-picker-input")
    |> Phoenix.LiveViewTest.render_change(%{"saved-location-picker_search" => text})

    context
  end

  defp choose_place(context, main_text, display_text, full_address, types) do
    session =
      select_location(context.session,
        id: "modal-address-autocomplete",
        place_id: "place-#{System.unique_integer([:positive])}",
        display_text: display_text,
        main_text: main_text,
        formatted_address: full_address,
        types: types,
        latitude: 30.1712,
        longitude: -81.6021,
        time_zone: "America/New_York"
      )

    Map.merge(context, %{session: session, conn: session})
  end

  defp address_text(session) do
    session.view
    |> Phoenix.LiveViewTest.render()
    |> LazyHTML.from_fragment()
    |> LazyHTML.query("#location-address-input")
    |> LazyHTML.text()
    |> String.trim_leading("\n")
  end
end
