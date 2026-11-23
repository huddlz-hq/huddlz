defmodule BrowserNavigationSteps do
  use Cucumber.StepDefinition

  import Huddlz.Test.BrowserHelpers
  import Fluffy.PhoenixTest

  step "I open mobile navigation with the keyboard", context do
    conn =
      context.conn
      |> assert_browser("document.querySelector('#mobile-navigation-drawer').inert")
      |> unwrap(&Playwright.Page.press!(&1, "#mobile-nav-trigger", "Enter"))
      |> assert_has("#mobile-nav-close:focus")

    Map.put(context, :conn, conn)
  end

  step "the drawer contains focus and the page behind it is inert", context do
    conn =
      context.conn
      |> assert_has("[data-mobile-nav-background][inert]")
      |> unwrap(&Playwright.Page.press!(&1, ":focus", "Shift+Tab"))
      |> assert_has("#mobile-navigation-drawer a[aria-label='huddlz home']:focus")
      |> unwrap(&Playwright.Page.press!(&1, ":focus", "Shift+Tab"))
      |> assert_has("#sidebar-user:focus")
      |> unwrap(&Playwright.Page.press!(&1, ":focus", "Tab"))
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
    Map.put(context, :conn, unwrap(context.conn, &Playwright.Page.press!(&1, ":focus", "Escape")))
  end

  step "focus returns to the navigation trigger and the page is usable", context do
    conn =
      context.conn
      |> assert_has("#mobile-nav-trigger:focus[aria-expanded='false']")
      |> assert_browser("document.querySelector('#mobile-navigation-drawer').inert")
      |> refute_has("[data-mobile-nav-background][inert]")
      |> unwrap(&Playwright.Page.press!(&1, ":focus", "Tab"))
      |> assert_browser(
        "document.querySelector('[data-mobile-nav-background]').contains(document.activeElement)"
      )

    Map.put(context, :conn, conn)
  end

  step "I reopen mobile navigation and visit Groups", context do
    conn =
      context.conn
      |> unwrap(&Playwright.Page.press!(&1, "#mobile-nav-trigger", "Enter"))
      |> click_link("#mobile-navigation-drawer a", "Groups")

    Map.put(context, :conn, conn)
  end

  step "Groups loads with the drawer closed and can reopen navigation", context do
    conn =
      context.conn
      |> assert_has("h1", text: "Groups")
      |> assert_has(".phx-connected")
      |> assert_browser("document.querySelector('#mobile-navigation-drawer').inert")
      |> refute_has("[data-mobile-nav-background][inert]")
      |> unwrap(&Playwright.Page.press!(&1, "#mobile-nav-trigger", "Enter"))
      |> assert_has("#mobile-nav-close:focus")
      |> assert_has("[data-mobile-nav-background][inert]")

    Map.put(context, :conn, conn)
  end
end
