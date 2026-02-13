defmodule LocationAutocompleteSteps do
  use Cucumber.StepDefinition
  import Mox
  import PhoenixTest

  @location_labels ["City / Region", "Location", "Physical Location"]

  step "I type {string} in the location field", %{args: [text]} = context do
    setup_autocomplete_stub(text)
    session = context[:session] || context[:conn]

    session = fill_in_location(session, text, @location_labels)

    Map.merge(context, %{session: session, conn: session})
  end

  step "I should see location suggestions", context do
    session = context[:session] || context[:conn]
    assert_has(session, "[phx-click='select_location']")
    context
  end

  step "I select {string} from the location suggestions", %{args: [text]} = context do
    setup_place_details_stub()
    session = context[:session] || context[:conn]
    session = click_button(session, text)
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

  defp fill_in_location(session, text, [label]) do
    fill_in(session, label, with: text)
  end

  defp fill_in_location(session, text, [label | rest]) do
    fill_in(session, label, with: text)
  rescue
    _ -> fill_in_location(session, text, rest)
  end

  defp setup_autocomplete_stub(text) do
    case text do
      "aus" ->
        stub(Huddlz.MockPlaces, :autocomplete, fn _, _token, _opts ->
          {:ok,
           [
             %{
               place_id: "p1",
               display_text: "Austin, TX, USA",
               main_text: "Austin",
               secondary_text: "TX, USA"
             }
           ]}
        end)

      "saint" ->
        stub(Huddlz.MockPlaces, :autocomplete, fn _, _token, _opts ->
          {:ok,
           [
             %{
               place_id: "p2",
               display_text: "Saint Augustine, FL, USA",
               main_text: "Saint Augustine",
               secondary_text: "FL, USA"
             }
           ]}
        end)

      _ ->
        stub(Huddlz.MockPlaces, :autocomplete, fn _, _token, _opts -> {:ok, []} end)
    end
  end

  defp setup_place_details_stub do
    stub(Huddlz.MockPlaces, :place_details, fn
      "p1", _token -> {:ok, %{latitude: 30.27, longitude: -97.74}}
      "p2", _token -> {:ok, %{latitude: 29.89, longitude: -81.31}}
      _, _token -> {:error, :not_found}
    end)
  end
end
