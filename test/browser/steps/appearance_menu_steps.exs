defmodule BrowserAppearanceMenuSteps do
  use Cucumber.StepDefinition

  import ExUnit.Assertions
  import Huddlz.Test.BrowserHelpers
  import Fluffy.PhoenixTest

  @menu_open "document.querySelector('#theme-menu').matches(':popover-open')"

  step "I open the appearance menu with the keyboard", context do
    conn =
      context.conn
      |> unwrap(&Playwright.Page.press!(&1, "#theme-menu-trigger", "Enter"))
      |> assert_browser(@menu_open)

    Map.put(context, :conn, conn)
  end

  step "I pick {string} with the keyboard", %{args: [label]} = context do
    conn = tab_to_option(context.conn, label)
    Map.put(context, :conn, unwrap(conn, &Playwright.Page.press!(&1, ":focus", "Enter")))
  end

  step "the page uses the dark appearance and the menu is closed", context do
    conn =
      assert_browser(
        context.conn,
        "document.documentElement.dataset.theme === 'dark' && !#{@menu_open}"
      )

    Map.put(context, :conn, conn)
  end

  step "I press Escape", context do
    Map.put(context, :conn, unwrap(context.conn, &Playwright.Page.press!(&1, ":focus", "Escape")))
  end

  step "the menu is closed and focus is back on its trigger", context do
    conn =
      context.conn
      |> assert_browser("!#{@menu_open}")
      |> assert_has("#theme-menu-trigger:focus")

    Map.put(context, :conn, conn)
  end

  # Tab from the trigger into the menu, one option at a time, until the
  # wanted one has focus.
  defp tab_to_option(conn, label, tries \\ 4)

  defp tab_to_option(_conn, label, 0), do: flunk("no appearance option labelled #{label}")

  defp tab_to_option(conn, label, tries) do
    conn = unwrap(conn, &Playwright.Page.press!(&1, ":focus", "Tab"))

    focused =
      unwrap_and_return(
        conn,
        &Playwright.Page.evaluate!(
          &1,
          "document.activeElement.querySelector('.theme-option-label')?.textContent"
        )
      )

    if focused == label, do: conn, else: tab_to_option(conn, label, tries - 1)
  end
end
