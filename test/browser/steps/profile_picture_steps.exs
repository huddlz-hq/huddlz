defmodule BrowserPictureSteps do
  use Cucumber.StepDefinition

  import ExUnit.Assertions
  import Huddlz.Test.BrowserHelpers
  import PhoenixTest
  import PhoenixTest.Playwright, only: [press: 3]

  step "I upload a profile picture through the file input", context do
    # The app intentionally hides its file input behind a visible upload label.
    assert {:ok, _} =
             PlaywrightEx.Frame.set_input_files(context.conn.frame_id,
               selector: "#avatar-form input[type=file]",
               timeout: 5_000,
               local_paths: [Path.expand("test/fixtures/test_image.jpg")]
             )

    conn = assert_has(context.conn, "#open-remove-avatar-dialog")

    Map.put(context, :conn, conn)
  end

  step "my uploaded picture is decoded and displayed by the browser", context do
    assert_browser(context.conn, """
    (() => {
      const image = document.querySelector('img.big-avatar');
      return image && image.complete && image.naturalWidth > 0 && image.getBoundingClientRect().width > 0;
    })()
    """)

    context
  end

  step "I open the remove picture confirmation with the keyboard", context do
    conn =
      context.conn
      |> press("#open-remove-avatar-dialog", "Enter")
      |> assert_has("#cancel-remove-avatar:focus")

    Map.put(context, :conn, conn)
  end

  step "I open the remove picture confirmation by clicking Remove", context do
    conn =
      context.conn
      |> click_button("Remove")
      |> assert_has("#remove-avatar-dialog [role='dialog']")

    Map.put(context, :conn, conn)
  end

  step "the Remove picture button is above the backdrop", context do
    assert_browser(context.conn, """
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

    context
  end

  step "I confirm picture removal by clicking Remove picture", context do
    Map.put(context, :conn, click_button(context.conn, "Remove picture"))
  end

  step "my profile picture is replaced by initials", context do
    conn =
      context.conn
      |> refute_has("#remove-avatar-dialog")
      |> assert_has("[role='alert']", text: "Profile picture removed")
      |> refute_has("img.big-avatar")
      |> assert_has("main .big-avatar", text: "BM")

    Map.put(context, :conn, conn)
  end

  step "Tab stays inside the confirmation dialog", context do
    conn =
      context.conn
      |> press(":focus", "Tab")
      |> assert_has("#confirm-remove-avatar:focus")
      |> press(":focus", "Tab")
      |> assert_has("#remove-avatar-dialog button[aria-label='close']:focus")
      |> press(":focus", "Tab")
      |> assert_has("#cancel-remove-avatar:focus")
      |> press(":focus", "Shift+Tab")
      |> assert_has("#remove-avatar-dialog button[aria-label='close']:focus")

    Map.put(context, :conn, conn)
  end

  step "I dismiss the confirmation with Escape", context do
    Map.put(context, :conn, press(context.conn, ":focus", "Escape"))
  end

  step "focus returns to Remove and my picture remains", context do
    context.conn
    |> refute_has("#remove-avatar-dialog")
    |> assert_has("#open-remove-avatar-dialog:focus")
    |> assert_has("img.big-avatar")

    context
  end
end
