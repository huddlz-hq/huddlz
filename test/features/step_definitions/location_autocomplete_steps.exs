defmodule LocationAutocompleteSteps do
  use Cucumber.StepDefinition
  import Huddlz.Test.MoxHelpers
  import PhoenixTest
  import Phoenix.LiveViewTest

  @component_ids ["location-autocomplete", "profile-location", "address-autocomplete"]

  step "I type {string} in the location field", %{args: [text]} = context do
    setup_autocomplete_stub(text)
    session = context[:session] || context[:conn]
    view = session.view

    # Find which location component is on the page and trigger its search event
    component_id = find_component_id(view)
    input_name = "#{component_id}_search"

    view
    |> element("##{component_id}-input")
    |> render_change(%{input_name => text})

    render_async(view)

    Map.merge(context, %{session: session, conn: session})
  end

  step "I should see location suggestions", context do
    session = context[:session] || context[:conn]
    assert_has(session, "[role='option']")
    context
  end

  step "I select {string} from the location suggestions", %{args: [text]} = context do
    setup_place_details_stub()
    session = context[:session] || context[:conn]
    view = session.view

    # Click the suggestion button via LiveViewTest (handles phx-target)
    view |> element("[role='option']", text) |> render_click()

    # Wait for async place_details if applicable
    render_async(view)

    Map.merge(context, %{session: session, conn: session})
  end

  step "I click on the selected location to edit it", context do
    session = context[:session] || context[:conn]
    view = session.view

    view |> element("[data-testid='location-selected'] [role='button']") |> render_click()

    Map.merge(context, %{session: session, conn: session})
  end

  step "I clear the selected location", context do
    session = context[:session] || context[:conn]
    view = session.view

    view |> element("[aria-label='Clear location']") |> render_click()

    Map.merge(context, %{session: session, conn: session})
  end

  step "I press the down arrow to highlight a suggestion", context do
    session = context[:session] || context[:conn]
    view = session.view

    component_id = find_component_id(view)

    view
    |> element("##{component_id}-input")
    |> render_keydown(%{"key" => "ArrowDown"})

    Map.merge(context, %{session: session, conn: session})
  end

  step "I press enter to select the highlighted suggestion", context do
    setup_place_details_stub()
    session = context[:session] || context[:conn]
    view = session.view

    component_id = find_component_id(view)

    view
    |> element("##{component_id}-input")
    |> render_keydown(%{"key" => "Enter"})

    render_async(view)

    Map.merge(context, %{session: session, conn: session})
  end

  step "the location filter should be active with {string}", %{args: [text]} = context do
    session = context[:session] || context[:conn]
    assert_has(session, "[data-testid='location-badge']", text: text)
    context
  end

  step "the location filter should not be active", context do
    session = context[:session] || context[:conn]
    refute_has(session, "[data-testid='location-badge']")
    context
  end

  defp find_component_id(view) do
    html = render(view)

    Enum.find(@component_ids, fn id -> html =~ ~s(id="#{id}-input") end) ||
      raise "Could not find any location autocomplete component on the page"
  end

  defp setup_autocomplete_stub(text) do
    results =
      case text do
        "aus" -> [:austin]
        "saint" -> [:saint_augustine]
        _ -> []
      end

    stub_places_autocomplete(%{text => results})
  end

  defp setup_place_details_stub, do: stub_place_details(:defaults)
end
