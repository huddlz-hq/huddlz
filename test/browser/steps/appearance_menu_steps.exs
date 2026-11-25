defmodule BrowserAppearanceMenuSteps do
  use Cucumber.StepDefinition
  use Fluffy.Assert

  import Fluffy, except: [step: 3]
  import Fluffy.Locator

  alias Fluffy.Playwright.Keyboard

  step "I open the appearance menu with the keyboard", %{session: session} do
    session
    |> press(trigger(), "Enter")
    |> assert(visible(open_menu()))

    :ok
  end

  step "I pick {string} with the keyboard", %{args: [label], session: session} do
    session
    |> tab_to_option(label)
    |> Keyboard.press("Enter")

    :ok
  end

  step "the page uses the dark appearance and the menu is closed", %{session: session} do
    session
    |> assert(attribute(by_css("html"), "data-theme", "dark"))
    |> refute(visible(open_menu()))

    :ok
  end

  step "I press Escape", %{session: session} do
    Keyboard.press(session, "Escape")
    :ok
  end

  step "the menu is closed and focus is back on its trigger", %{session: session} do
    session
    |> refute(visible(open_menu()))
    |> assert(focused(trigger()))

    :ok
  end

  defp trigger, do: by_role(:button, name: ~r/^Appearance: /)
  defp open_menu, do: by_css("#theme-menu:popover-open")

  # Tab from the trigger into the menu, one option at a time, until the
  # wanted one has focus.
  defp tab_to_option(session, label, tries \\ 4)

  defp tab_to_option(_session, label, 0), do: flunk("no appearance option labelled #{label}")

  defp tab_to_option(session, label, tries) do
    session = Keyboard.press(session, "Tab")

    focused =
      Fluffy.Playwright.evaluate(
        session,
        "document.activeElement.querySelector('.theme-option-label')?.textContent"
      )

    if focused == label, do: session, else: tab_to_option(session, label, tries - 1)
  end
end
