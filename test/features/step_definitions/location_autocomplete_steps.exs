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

    # Legacy variant uses a pencil button (`role="button"`); the v3 form variant
    # uses an explicit "Change location…" button. Either fires `phx-click="edit"`.
    edit_selector =
      if has_element?(view, "[data-testid='location-selected'] [role='button']") do
        "[data-testid='location-selected'] [role='button']"
      else
        "[data-testid='location-selected'] [phx-click='edit']"
      end

    view |> element(edit_selector) |> render_click()

    Map.merge(context, %{session: session, conn: session})
  end

  step "I clear the selected location", context do
    session = context[:session] || context[:conn]
    view = session.view

    # Legacy + filter-pill variants expose the clear button via aria-label;
    # the v3 form variant uses an explicit "Clear" text button.
    clear_selector =
      if has_element?(view, "[aria-label='Clear location']") do
        "[aria-label='Clear location']"
      else
        "[data-testid='location-selected'] [phx-click='clear']"
      end

    view |> element(clear_selector) |> render_click()

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
    # The v3 filter pill renders the active location as the value of an
    # `<input data-testid='location-display'>`; the legacy autocomplete (used
    # by other LiveViews) renders the same text inside a `<span>`. Match
    # whichever is on the page.
    try do
      assert_has(session, "[data-testid='location-display'][value='#{text}']")
    rescue
      ExUnit.AssertionError ->
        assert_has(session, "[data-testid='location-display']", text: text)
    end

    context
  end

  step "the location filter should not be active", context do
    session = context[:session] || context[:conn]
    refute_has(session, "[data-testid='location-display']")
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
