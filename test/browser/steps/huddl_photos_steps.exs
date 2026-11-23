defmodule BrowserPhotoSteps do
  use Cucumber.StepDefinition
  import Huddlz.Generator
  import Huddlz.Test.BrowserHelpers
  import Fluffy.PhoenixTest

  step "I am viewing my completed huddl in the browser", context do
    owner = generate(user(display_name: "Sam Rivera"))
    group = generate(group(owner_id: owner.id, actor: owner))
    huddl = generate(past_huddl(group_id: group.id, creator_id: owner.id))

    ExUnit.Callbacks.on_exit(fn ->
      File.rm_rf!("priv/static/uploads/huddl_photos/#{huddl.id}")
    end)

    conn =
      context.conn
      |> sign_in(owner)
      |> visit("/groups/#{group.slug}/huddlz/#{huddl.id}")

    Map.merge(context, %{conn: conn, huddl: huddl})
  end

  step "I select a valid photo and an oversized photo", context do
    path = Path.join(System.tmp_dir!(), "oversized-#{context.huddl.id}.jpg")
    File.write!(path, :binary.copy(<<0>>, 6_000_000))
    ExUnit.Callbacks.on_exit(fn -> File.rm(path) end)

    unwrap(
      context.conn,
      &Playwright.Page.set_input_files!(&1, "#huddl-photo-upload-form input[type=file]", [
        Path.expand("test/fixtures/test_image.jpg"),
        path
      ])
    )

    context
  end

  step "I can upload the valid photo and understand why the other was skipped", context do
    conn =
      context.conn
      |> assert_has(".upload-error", text: "Each photo must be 5 MB or smaller.")
      |> click_button("Upload photos")
      |> assert_has(".photo-tile", count: 1)
      |> assert_has("#flash-info", text: "Photos uploaded.")

    assert_browser(
      conn,
      "[...document.querySelectorAll('.photo-tile img')].every(i => i.complete && i.naturalWidth > 0)"
    )

    context
  end

  step "I select a corrupt image and submit it", context do
    unwrap(
      context.conn,
      &Playwright.Page.set_input_files!(&1, "#huddl-photo-upload-form input[type=file]", [
        Path.expand("test/fixtures/corrupt_image.jpg")
      ])
    )

    Map.put(context, :conn, click_button(context.conn, "Upload photos"))
  end

  step "I am told to choose a supported image instead of retrying it", context do
    context.conn
    |> assert_has(".upload-error", text: "corrupt_image.jpg: Choose a JPG, PNG, or WebP image.")
    |> refute_has(".photo-tile")
    |> refute_has("#flash-error", text: "Please try again.")

    context
  end

  step "I choose two photos using the keyboard upload control", context do
    conn =
      context.conn
      |> unwrap(&Playwright.Page.press!(&1, "#huddl-hero-group", "Tab"))
      |> assert_has("#browse-photos:focus")
      |> unwrap(&Playwright.Page.press!(&1, ":focus", "Enter"))

    unwrap(
      conn,
      &Playwright.Page.set_input_files!(&1, "#huddl-photo-upload-form input[type=file]", [
        Path.expand("test/fixtures/test_image.jpg"),
        Path.expand("priv/static/icon-512.png")
      ])
    )

    Map.put(context, :conn, conn)
  end

  step "the upload queue names each photo and its remove control", context do
    context.conn
    |> assert_has(".photo-upload-entry", text: "test_image.jpg")
    |> assert_has("button[aria-label='Remove test_image.jpg']")
    |> assert_has("button[aria-label='Remove icon-512.png']")

    context
  end

  step "I share the selected photos and open the first one", context do
    conn =
      context.conn
      |> click_button("Upload photos")
      |> assert_has(".photo-tile", count: 2)
      |> refute_has(".photo-upload-entry")

    conn =
      unwrap(conn, &Playwright.Page.press!(&1, ".photo-tile:first-child .photo-open", "Enter"))

    Map.put(context, :conn, conn)
  end

  step "Tab and Shift+Tab stay inside the photo viewer", context do
    conn =
      context.conn
      |> assert_has("#photo-lightbox button[aria-label='Previous photo']:focus")
      |> unwrap(&Playwright.Page.press!(&1, ":focus", "Tab"))
      |> assert_has("#photo-lightbox button[aria-label='Next photo']:focus")
      |> unwrap(&Playwright.Page.press!(&1, ":focus", "Tab"))
      |> assert_has("#photo-lightbox .lightbox-actions button:focus", text: "Close")
      |> unwrap(&Playwright.Page.press!(&1, ":focus", "Tab"))
      |> assert_has("#photo-lightbox button[aria-label='close']:focus")
      |> unwrap(&Playwright.Page.press!(&1, ":focus", "Tab"))
      |> assert_has("#photo-lightbox button[aria-label='Previous photo']:focus")
      |> unwrap(&Playwright.Page.press!(&1, ":focus", "Shift+Tab"))
      |> assert_has("#photo-lightbox button[aria-label='close']:focus")

    Map.put(context, :conn, conn)
  end

  step "I can navigate with arrow keys and see the contributor and photo position", context do
    conn =
      context.conn
      |> assert_has("#photo-lightbox [role='dialog']", text: "Sam Rivera")
      |> assert_has("#photo-position", text: "1 of 2")
      |> unwrap(&Playwright.Page.press!(&1, ":focus", "ArrowRight"))
      |> assert_has("#photo-position", text: "2 of 2")
      |> unwrap(&Playwright.Page.press!(&1, ":focus", "ArrowRight"))
      |> assert_has("#photo-position", text: "1 of 2")
      |> unwrap(&Playwright.Page.press!(&1, ":focus", "ArrowLeft"))
      |> assert_has("#photo-position", text: "2 of 2")

    Map.put(context, :conn, conn)
  end

  step "Escape returns focus to the photo I opened", context do
    conn =
      context.conn
      |> unwrap(&Playwright.Page.press!(&1, ":focus", "Escape"))
      |> assert_browser("!document.querySelector('#photo-lightbox')")
      |> assert_has(".photo-tile:first-child .photo-open:focus")

    Map.put(context, :conn, conn)
  end

  step "the gallery fits above the huddl details on mobile", context do
    assert_browser(context.conn, """
    (() => {
      const gallery = document.querySelector('.huddl-photos').getBoundingClientRect();
      const details = document.querySelector('.huddl-side').getBoundingClientRect();
      return document.documentElement.scrollWidth <= innerWidth && gallery.bottom <= details.top + 1;
    })()
    """)

    context
  end

  step "I consider deleting the first photo", context do
    Map.put(
      context,
      :conn,
      unwrap(
        context.conn,
        &Playwright.Page.press!(&1, ".photo-tile:first-child .photo-delete", "Enter")
      )
    )
  end

  step "Tab and Shift+Tab stay inside the photo deletion dialog", context do
    conn =
      context.conn
      |> assert_has("#cancel-delete-photo:focus")
      |> unwrap(&Playwright.Page.press!(&1, ":focus", "Tab"))
      |> assert_has("#confirm-delete-photo:focus")
      |> unwrap(&Playwright.Page.press!(&1, ":focus", "Tab"))
      |> assert_has("#delete-photo-modal button[aria-label='close']:focus")
      |> unwrap(&Playwright.Page.press!(&1, ":focus", "Tab"))
      |> assert_has("#cancel-delete-photo:focus")
      |> unwrap(&Playwright.Page.press!(&1, ":focus", "Shift+Tab"))
      |> assert_has("#delete-photo-modal button[aria-label='close']:focus")
      |> unwrap(&Playwright.Page.press!(&1, ":focus", "Tab"))
      |> assert_has("#cancel-delete-photo:focus")

    Map.put(context, :conn, conn)
  end

  step "I see which photo will be deleted and can keep it", context do
    conn =
      context.conn
      |> assert_has("#delete-photo-modal img")
      |> assert_has("#delete-photo-modal [role='dialog']", text: "Sam Rivera")
      |> unwrap(&Playwright.Page.press!(&1, ":focus", "Enter"))
      |> refute_has("#delete-photo-modal [role='dialog']")
      |> assert_has(".photo-tile", count: 2)

    assert_has(conn, ".photo-tile:first-child .photo-delete:focus")
    context
  end
end
