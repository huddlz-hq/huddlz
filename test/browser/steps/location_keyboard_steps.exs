defmodule BrowserLocationKeyboardSteps do
  use Cucumber.StepDefinition

  import ExUnit.Assertions
  import Huddlz.Generator
  import Huddlz.Test.BrowserHelpers
  import Huddlz.Test.MoxHelpers
  import Fluffy.PhoenixTest

  step "I have opened my profile in a browser", context do
    member = generate(user(role: :user, display_name: "Browser Member"))

    stub_places_autocomplete(%{"saint" => [:saint_augustine]})
    stub_place_details(:defaults)

    conn =
      context.conn
      |> sign_in(member)
      |> visit("/profile")
      |> assert_has("h1", text: "Profile")
      |> unwrap(fn page ->
        assert Playwright.Page.evaluate!(page, """
               (() => {
                 window.observedSubmissions = 0;
                 document.addEventListener('submit', () => window.observedSubmissions++, true);
                 return true;
               })()
               """)
      end)

    ExUnit.Callbacks.on_exit(fn ->
      File.rm_rf!("priv/static/uploads/profile_pictures/#{member.id}")
    end)

    Map.put(context, :conn, conn)
  end

  step "I type {string} into my home location", %{args: [query]} = context do
    conn =
      context.conn
      |> unwrap(
        &(&1
          |> Playwright.Page.locator("#profile-location-input")
          |> Playwright.Locator.press_sequentially!(query))
      )
      |> assert_has("[role='option']")

    Map.put(context, :conn, conn)
  end

  step "I highlight the first home location suggestion", context do
    conn =
      context.conn
      |> unwrap(&Playwright.Page.press!(&1, "#profile-location-input", "ArrowDown"))
      |> assert_has("#profile-location[data-has-highlight='true']")

    Map.put(context, :conn, conn)
  end

  step "I select the highlighted home location with Enter", context do
    Map.put(
      context,
      :conn,
      unwrap(context.conn, &Playwright.Page.press!(&1, "#profile-location-input", "Enter"))
    )
  end

  step "my home location is {string}", %{args: [location]} = context do
    context.conn
    |> assert_has("[data-testid='location-selected']", text: location)
    |> assert_has("[role='alert']", text: "Home location updated")

    context
  end

  step "Enter did not submit a form", context do
    unwrap(context.conn, fn page ->
      assert Playwright.Page.evaluate!(page, "window.observedSubmissions") == 0
    end)

    context
  end
end
