defmodule LandingSearchSteps do
  @moduledoc """
  Steps for the landing page search when the picked place's details are slow
  to arrive. The place details stub waits for the scenario to release it, so
  the search can be submitted while the place is still loading.
  """
  use Cucumber.StepDefinition
  import Huddlz.Test.MoxHelpers
  import Mox
  import PhoenixTest
  import Phoenix.LiveViewTest
  import ExUnit.Assertions

  step "I pick {string} from the location suggestions while its details are still loading",
       %{args: [text]} = context do
    scenario = self()

    stub(Huddlz.MockPlaces, :place_details, fn place_id, _token ->
      send(scenario, {:place_details_requested, self()})

      receive do
        :release -> {:ok, Map.fetch!(known_coords(), place_id)}
      end
    end)

    session = context[:session] || context[:conn]
    session.view |> element("[role='option']", text) |> render_click()

    assert_receive {:place_details_requested, lookup}
    Map.put(context, :place_details_lookup, lookup)
  end

  step "the search waits for the place", context do
    session = context[:session] || context[:conn]
    assert_path(session, "/")
    assert render(session.view) =~ "Find a huddl"
    context
  end

  step "the place details arrive", context do
    send(context.place_details_lookup, :release)
    context
  end

  step "Discover opens searching near {string}", %{args: [place]} = context do
    session = context[:session] || context[:conn]
    {path, _flash} = assert_redirect(session.view, 1_000)
    session = visit(session, path)
    assert_has(session, "[data-testid='location-display'][value='#{place}']")
    Map.merge(context, %{session: session, conn: session})
  end
end
