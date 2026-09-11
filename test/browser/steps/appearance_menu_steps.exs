defmodule BrowserAppearanceMenuSteps do
  use Cucumber.StepDefinition

  import ExUnit.Assertions
  import Huddlz.Test.BrowserHelpers
  import PhoenixTest
  import PhoenixTest.Playwright, only: [press: 3]

  @menu_open "document.querySelector('#theme-menu').matches(':popover-open')"

  step "I open the appearance menu with the keyboard", context do
    conn =
      context.conn
      |> press("#theme-menu-trigger", "Enter")
      |> assert_browser(@menu_open)

    Map.put(context, :conn, conn)
  end

  step "I pick {string} with the keyboard", %{args: [label]} = context do
    conn = tab_to_option(context.conn, label)
    Map.put(context, :conn, press(conn, ":focus", "Enter"))
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
    Map.put(context, :conn, press(context.conn, ":focus", "Escape"))
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
    conn = press(conn, ":focus", "Tab")

    {:ok, focused} =
      PlaywrightEx.Frame.evaluate(conn.frame_id,
        expression: "document.activeElement.querySelector('.theme-option-label')?.textContent",
        timeout: 5_000
      )

    if focused == label, do: conn, else: tab_to_option(conn, label, tries - 1)
  end
end
