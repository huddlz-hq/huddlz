defmodule BrowserNavigationSteps do
  use Cucumber.StepDefinition
  use Fluffy.Assert

  import Fluffy, except: [step: 3]
  import Fluffy.Locator

  alias Fluffy.Playwright.Keyboard

  step "I open mobile navigation with the keyboard", %{session: session} do
    session
    |> assert(inert(drawer()))
    |> press(trigger(), "Enter")
    |> assert(focused(close_button()))

    :ok
  end

  step "the drawer contains focus and the page behind it is inert", %{session: session} do
    home = by_role(drawer(), :link, name: "huddlz home")

    session
    |> assert(inert(background()))
    |> Keyboard.press("Shift+Tab")
    |> assert(focused(home))
    |> Keyboard.press("Shift+Tab")
    |> assert(focused(by_role(:link, name: "View profile")))
    |> Keyboard.press("Tab")
    |> assert(focused(home))
    |> assert(in_viewport(drawer(), ratio: 1))

    :ok
  end

  step "I close mobile navigation with Escape", %{session: session} do
    Keyboard.press(session, "Escape")
    :ok
  end

  step "focus returns to the navigation trigger and the page is usable", %{session: session} do
    session
    |> assert(focused(trigger()))
    |> assert(attribute(trigger(), "aria-expanded", "false"))
    |> assert(inert(drawer()))
    |> refute(inert(background()))
    |> Keyboard.press("Tab")
    |> assert(attached(by_css("[data-mobile-nav-background] :focus")))

    :ok
  end

  step "I reopen mobile navigation and visit Groups", %{session: session} do
    session
    |> press(trigger(), "Enter")
    |> click(by_role(drawer(), :link, name: "Groups", exact: true))

    :ok
  end

  step "Groups loads with the drawer closed and can reopen navigation", %{session: session} do
    session
    |> assert_has(by_role(:heading, level: 1, name: "Groups"))
    |> assert(inert(drawer()))
    |> refute(inert(background()))
    |> press(trigger(), "Enter")
    |> assert(focused(close_button()))
    |> assert(inert(background()))

    :ok
  end

  defp drawer, do: by_css("#mobile-navigation-drawer")
  defp background, do: by_css("[data-mobile-nav-background]")
  defp trigger, do: by_role(:button, name: "Open navigation", exact: true)
  defp close_button, do: by_role(:button, name: "Close navigation", exact: true)
  defp inert(locator), do: js_property(locator, "inert", true)
end
