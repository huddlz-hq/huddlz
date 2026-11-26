defmodule BrowserPictureSteps do
  use Cucumber.StepDefinition
  use Fluffy.Assert

  import Fluffy, except: [step: 3]
  import Fluffy.Locator
  import Huddlz.Test.BrowserHelpers

  alias Fluffy.Playwright.Keyboard

  step "I upload a profile picture through the file input", %{session: session} do
    # The app intentionally hides its file input behind a visible upload label.
    # The crop sheet opens first; the picture is used as it is.
    session
    |> set_input_files(by_label("Upload a photo…", exact: true), "test/fixtures/test_image.jpg")
    |> assert_has(by_css("#avatar-upload-crop[open]"))
    |> click(by_role(:button, name: "Use photo"))
    |> assert_has(remove())

    :ok
  end

  step "my uploaded picture is decoded and displayed by the browser", %{session: session} do
    assert_browser(session, """
    (() => {
      const image = document.querySelector('img.big-avatar');
      return image && image.complete && image.naturalWidth > 0 && image.getBoundingClientRect().width > 0;
    })()
    """)

    :ok
  end

  step "I open the remove picture confirmation with the keyboard", %{session: session} do
    session
    |> press(remove(), "Enter")
    |> assert(focused(keep()))

    :ok
  end

  step "I open the remove picture confirmation by clicking Remove", %{session: session} do
    session
    |> click(remove())
    |> assert_has(dialog())

    :ok
  end

  step "the Remove picture button is above the backdrop", %{session: session} do
    assert_browser(session, """
    (() => {
      const button = document.querySelector('#confirm-remove-avatar');
      if (!button) return false;
      const rect = button.getBoundingClientRect();
      const topElement = document.elementFromPoint(
        rect.left + rect.width / 2, rect.top + rect.height / 2
      );
      return rect.width > 0 && rect.height > 0 && button.contains(topElement);
    })()
    """)

    :ok
  end

  step "I confirm picture removal by clicking Remove picture", %{session: session} do
    click(session, confirm())
    :ok
  end

  step "my profile picture is replaced by initials", %{session: session} do
    session
    |> assert(count(dialog(), 0))
    |> assert_has(by_role(:alert) |> filter(has_text: "Profile picture removed"))
    |> assert(count(by_css("img.big-avatar"), 0))
    |> assert_has(by_css("main .big-avatar") |> filter(has_text: "BM"))

    :ok
  end

  step "Tab stays inside the confirmation dialog", %{session: session} do
    close = by_role(by_css("#remove-avatar-dialog"), :button, name: "close", exact: true)

    session
    |> Keyboard.press("Tab")
    |> assert(focused(confirm()))
    |> Keyboard.press("Tab")
    |> assert(focused(close))
    |> Keyboard.press("Tab")
    |> assert(focused(keep()))
    |> Keyboard.press("Shift+Tab")
    |> assert(focused(close))

    :ok
  end

  step "I dismiss the confirmation with Escape", %{session: session} do
    Keyboard.press(session, "Escape")
    :ok
  end

  step "focus returns to Remove and my picture remains", %{session: session} do
    session
    |> assert(count(dialog(), 0))
    |> assert(focused(remove()))
    |> assert_has(by_css("img.big-avatar"))

    :ok
  end

  defp remove, do: by_role(:button, name: "Remove", exact: true)
  defp dialog, do: by_role(by_css("#remove-avatar-dialog"), :dialog)
  defp keep, do: by_role(dialog(), :button, name: "Keep picture")
  defp confirm, do: by_role(dialog(), :button, name: "Remove picture")
end
