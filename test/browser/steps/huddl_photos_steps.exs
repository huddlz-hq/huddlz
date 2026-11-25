defmodule BrowserPhotoSteps do
  use Cucumber.StepDefinition
  use Fluffy.Assert

  import Fluffy, except: [step: 2, step: 3]
  import Fluffy.Locator
  import Huddlz.Generator
  import Huddlz.Test.BrowserHelpers

  alias Fluffy.Event
  alias Fluffy.Playwright.Keyboard

  step "I am viewing my completed huddl in the browser", %{session: session} do
    owner = generate(user(display_name: "Sam Rivera"))
    group = generate(group(owner_id: owner.id, actor: owner))
    huddl = generate(past_huddl(group_id: group.id, creator_id: owner.id))

    ExUnit.Callbacks.on_exit(fn ->
      File.rm_rf!("priv/static/uploads/huddl_photos/#{huddl.id}")
    end)

    session
    |> sign_in(owner)
    |> visit("/groups/#{group.slug}/huddlz/#{huddl.id}")

    %{huddl: huddl}
  end

  step "I select a valid photo and an oversized photo", %{session: session} = context do
    path = Path.join(System.tmp_dir!(), "oversized-#{context.huddl.id}.jpg")
    File.write!(path, :binary.copy(<<0>>, 6_000_000))
    ExUnit.Callbacks.on_exit(fn -> File.rm(path) end)

    set_input_files(session, photo_input(), ["test/fixtures/test_image.jpg", path])
    :ok
  end

  step "I can upload the valid photo and understand why the other was skipped",
       %{session: session} do
    session
    |> assert(visible(upload_error("Each photo must be 5 MB or smaller.")))
    |> click(upload_button())
    |> assert(count(tiles(), 1))
    |> assert(visible(by_css("#flash-info") |> filter(has_text: "Photos uploaded.")))
    |> assert_browser(
      "[...document.querySelectorAll('.photo-tile img')].every(i => i.complete && i.naturalWidth > 0)"
    )

    :ok
  end

  step "I select a corrupt image and submit it", %{session: session} do
    session
    |> set_input_files(photo_input(), "test/fixtures/corrupt_image.jpg")
    |> click(upload_button())

    :ok
  end

  step "I am told to choose a supported image instead of retrying it", %{session: session} do
    session
    |> assert(visible(upload_error("corrupt_image.jpg: Choose a JPG, PNG, or WebP image.")))
    |> assert(count(tiles(), 0))
    |> refute(visible(by_css("#flash-error") |> filter(has_text: "Please try again.")))

    :ok
  end

  step "I choose two photos using the keyboard upload control", %{session: session} do
    session
    |> press(by_css("#huddl-hero-group"), "Tab")
    |> assert(focused(by_role(:button, name: "Browse photos")))

    # Enter on the control opens the browser's file chooser.
    chooser = wait_for(session, Event.file_chooser())
    Keyboard.press(session, "Enter")

    set_input_files(session, await(chooser), [
      "test/fixtures/test_image.jpg",
      "priv/static/icon-512.png"
    ])

    :ok
  end

  step "the upload queue names each photo and its remove control", %{session: session} do
    session
    |> assert(visible(by_css(".photo-upload-entry") |> filter(has_text: "test_image.jpg")))
    |> assert(visible(by_role(:button, name: "Remove test_image.jpg", exact: true)))
    |> assert(visible(by_role(:button, name: "Remove icon-512.png", exact: true)))

    :ok
  end

  step "I share the selected photos and open the first one", %{session: session} do
    session
    |> click(upload_button())
    |> assert(count(tiles(), 2))
    |> assert(count(by_css(".photo-upload-entry"), 0))
    |> press(first_tile_button("View photo"), "Enter")

    :ok
  end

  step "Tab and Shift+Tab stay inside the photo viewer", %{session: session} do
    lightbox = by_css("#photo-lightbox")

    session
    |> assert(focused(by_role(lightbox, :button, name: "Previous photo")))
    |> Keyboard.press("Tab")
    |> assert(focused(by_role(lightbox, :button, name: "Next photo")))
    |> Keyboard.press("Tab")
    |> assert(focused(by_role(lightbox, :button, name: "Close", exact: true)))
    |> Keyboard.press("Tab")
    |> assert(focused(by_role(lightbox, :button, name: "close", exact: true)))
    |> Keyboard.press("Tab")
    |> assert(focused(by_role(lightbox, :button, name: "Previous photo")))
    |> Keyboard.press("Shift+Tab")
    |> assert(focused(by_role(lightbox, :button, name: "close", exact: true)))

    :ok
  end

  step "I can navigate with arrow keys and see the contributor and photo position",
       %{session: session} do
    position = by_css("#photo-position")

    session
    |> assert(
      visible(by_role(by_css("#photo-lightbox"), :dialog) |> filter(has_text: "Sam Rivera"))
    )
    |> assert(text(position, "1 of 2"))
    |> Keyboard.press("ArrowRight")
    |> assert(text(position, "2 of 2"))
    |> Keyboard.press("ArrowRight")
    |> assert(text(position, "1 of 2"))
    |> Keyboard.press("ArrowLeft")
    |> assert(text(position, "2 of 2"))

    :ok
  end

  step "Escape returns focus to the photo I opened", %{session: session} do
    session
    |> Keyboard.press("Escape")
    |> assert(count(by_css("#photo-lightbox"), 0))
    |> assert(focused(first_tile_button("View photo")))

    :ok
  end

  step "the gallery fits above the huddl details on mobile", %{session: session} do
    assert_browser(session, """
    (() => {
      const gallery = document.querySelector('.huddl-photos').getBoundingClientRect();
      const details = document.querySelector('.huddl-side').getBoundingClientRect();
      return document.documentElement.scrollWidth <= innerWidth && gallery.bottom <= details.top + 1;
    })()
    """)

    :ok
  end

  step "I consider deleting the first photo", %{session: session} do
    press(session, first_tile_button("Delete photo"), "Enter")
    :ok
  end

  step "Tab and Shift+Tab stay inside the photo deletion dialog", %{session: session} do
    modal = by_css("#delete-photo-modal")
    keep = by_role(modal, :button, name: "Keep photo")
    delete = by_role(modal, :button, name: "Delete photo")
    close = by_role(modal, :button, name: "close", exact: true)

    session
    |> assert(focused(keep))
    |> Keyboard.press("Tab")
    |> assert(focused(delete))
    |> Keyboard.press("Tab")
    |> assert(focused(close))
    |> Keyboard.press("Tab")
    |> assert(focused(keep))
    |> Keyboard.press("Shift+Tab")
    |> assert(focused(close))
    |> Keyboard.press("Tab")
    |> assert(focused(keep))

    :ok
  end

  step "I see which photo will be deleted and can keep it", %{session: session} do
    dialog = by_role(by_css("#delete-photo-modal"), :dialog)

    session
    |> assert(visible(by_css("#delete-photo-modal img")))
    |> assert(visible(dialog |> filter(has_text: "Sam Rivera")))
    |> Keyboard.press("Enter")
    |> assert(count(dialog, 0))
    |> assert(count(tiles(), 2))
    |> assert(focused(first_tile_button("Delete photo")))

    :ok
  end

  defp photo_input, do: by_label("Photos", exact: true)
  defp upload_button, do: by_role(:button, name: "Upload photos")
  defp tiles, do: by_css(".photo-tile")
  defp upload_error(text), do: by_css(".upload-error") |> filter(has_text: text)

  defp first_tile_button(name),
    do: by_role(tiles() |> first(), :button, name: name, exact: true)
end
