defmodule BrowserNavigationSteps do
  use Cucumber.StepDefinition

  import Huddlz.Test.BrowserHelpers
  import PhoenixTest
  import PhoenixTest.Playwright, only: [press: 3]

  step "I open mobile navigation with the keyboard", context do
    conn =
      context.conn
      |> assert_browser("document.querySelector('#mobile-navigation-drawer').inert")
      |> press("#mobile-nav-trigger", "Enter")
      |> assert_has("#mobile-nav-close:focus")

    Map.put(context, :conn, conn)
  end

  step "the drawer contains focus and the page behind it is inert", context do
    conn =
      context.conn
      |> assert_has("[data-mobile-nav-background][inert]")
      |> press(":focus", "Shift+Tab")
      |> assert_has("#mobile-navigation-drawer a[aria-label='huddlz home']:focus")
      |> press(":focus", "Shift+Tab")
      |> assert_has("#sidebar-user:focus")
      |> press(":focus", "Tab")
      |> assert_has("#mobile-navigation-drawer a[aria-label='huddlz home']:focus")
      |> assert_browser("""
      (() => {
        const drawer = document.querySelector('#mobile-navigation-drawer').getBoundingClientRect();
        return drawer.left >= 0 && drawer.right <= innerWidth;
      })()
      """)

    Map.put(context, :conn, conn)
  end

  step "I close mobile navigation with Escape", context do
    Map.put(context, :conn, press(context.conn, ":focus", "Escape"))
  end

  step "focus returns to the navigation trigger and the page is usable", context do
    conn =
      context.conn
      |> assert_has("#mobile-nav-trigger:focus[aria-expanded='false']")
      |> assert_browser("document.querySelector('#mobile-navigation-drawer').inert")
      |> refute_has("[data-mobile-nav-background][inert]")
      |> press(":focus", "Tab")
      |> assert_browser(
        "document.querySelector('[data-mobile-nav-background]').contains(document.activeElement)"
      )

    Map.put(context, :conn, conn)
  end

  step "I reopen mobile navigation and visit My groups", context do
    conn =
      context.conn
      |> press("#mobile-nav-trigger", "Enter")
      |> click_link("#mobile-navigation-drawer a", "My groups")

    Map.put(context, :conn, conn)
  end

  step "My groups loads with the drawer closed and can reopen navigation", context do
    conn =
      context.conn
      |> assert_has("h1", text: "My groups")
      |> assert_has(".phx-connected")
      |> assert_browser("document.querySelector('#mobile-navigation-drawer').inert")
      |> refute_has("[data-mobile-nav-background][inert]")
      |> press("#mobile-nav-trigger", "Enter")
      |> assert_has("#mobile-nav-close:focus")
      |> assert_has("[data-mobile-nav-background][inert]")

    Map.put(context, :conn, conn)
  end
end
