defmodule BrowserLocationKeyboardSteps do
  use Cucumber.StepDefinition
  use Fluffy.Assert

  import Fluffy, except: [step: 3]
  import Fluffy.Locator
  import Huddlz.Generator
  import Huddlz.Test.BrowserHelpers
  import Huddlz.Test.MoxHelpers

  step "I have opened my profile in a browser", %{session: session} do
    member = generate(user(role: :user, display_name: "Browser Member"))

    stub_places_autocomplete(%{"saint" => [:saint_augustine]})
    stub_place_details(:defaults)

    session
    |> sign_in(member)
    |> visit("/profile")
    |> assert(visible(by_role(:heading, level: 1, name: "Profile")))

    assert Fluffy.Playwright.evaluate(session, """
           (() => {
             window.observedSubmissions = 0;
             document.addEventListener('submit', () => window.observedSubmissions++, true);
             return true;
           })()
           """)

    ExUnit.Callbacks.on_exit(fn ->
      File.rm_rf!("priv/static/uploads/profile_pictures/#{member.id}")
    end)

    :ok
  end

  step "I type {string} into my home location", %{args: [query], session: session} do
    session
    |> Fluffy.Playwright.press_sequentially(home_location(), query)
    |> assert(visible(by_role(:option) |> first()))

    :ok
  end

  step "I highlight the first home location suggestion", %{session: session} do
    session
    |> press(home_location(), "ArrowDown")
    |> assert(attribute(by_css("#profile-location"), "data-has-highlight", "true"))

    :ok
  end

  step "I select the highlighted home location with Enter", %{session: session} do
    press(session, home_location(), "Enter")
    :ok
  end

  step "my home location is {string}", %{args: [location], session: session} do
    session
    |> assert(visible(by_test_id("location-selected") |> filter(has_text: location)))
    |> assert(visible(by_role(:alert) |> filter(has_text: "Home location updated")))

    :ok
  end

  step "Enter did not submit a form", %{session: session} do
    assert Fluffy.Playwright.evaluate(session, "window.observedSubmissions") == 0
    :ok
  end

  defp home_location, do: by_label("Location", exact: true)
end
