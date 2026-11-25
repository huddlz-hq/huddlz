defmodule BrowserCoverCropSteps do
  use Cucumber.StepDefinition
  use Fluffy.Assert

  import Fluffy, except: [step: 3]
  import Fluffy.Locator
  import Huddlz.Generator
  import Huddlz.Test.BrowserHelpers

  require Ash.Query

  alias Fluffy.Playwright.Mouse

  step "I am creating a group in a browser", %{session: session} do
    owner = generate(user(role: :user))

    ExUnit.Callbacks.on_exit(fn ->
      File.rm_rf!("priv/static/uploads/group_images/pending")
    end)

    session
    |> sign_in(owner)
    |> visit("/groups/new")
    |> assert(visible(by_css("#group-cover-upload[data-state=idle]")))

    :ok
  end

  step "I choose a tall picture for the cover", %{session: session} do
    set_input_files(
      session,
      by_label("Cover image", exact: true),
      "test/fixtures/tall_red_blue.png"
    )

    :ok
  end

  step "the crop sheet opens with the picture fit to the 16:9 window", %{session: session} do
    assert_browser(session, """
    (() => {
      const sheet = document.querySelector('#group-cover-upload-crop');
      if (!sheet || !sheet.open) return false;
      const pic = sheet.querySelector('.crop-pic');
      const win = sheet.querySelector('.crop-window').getBoundingClientRect();
      const rect = pic.getBoundingClientRect();
      return pic.complete && pic.naturalWidth > 0 &&
        Math.abs(win.width / win.height - 16 / 9) < 0.02 &&
        Math.abs(rect.width - win.width) < 1 && rect.height > win.height &&
        Math.abs((rect.top + rect.bottom) / 2 - (win.top + win.bottom) / 2) < 1;
    })()
    """)

    :ok
  end

  step "the crop sheet fills the screen with the window and Use photo in view",
       %{session: session} do
    assert_browser(session, """
    (() => {
      const sheet = document.querySelector('#group-cover-upload-crop');
      if (!sheet || !sheet.open) return false;
      const rect = sheet.getBoundingClientRect();
      const win = sheet.querySelector('.crop-window').getBoundingClientRect();
      const use = sheet.querySelector('[data-crop-use]').getBoundingClientRect();
      const stage = sheet.querySelector('[data-crop-stage]');
      return rect.width === window.innerWidth && rect.height === window.innerHeight &&
        Math.abs(win.width - (window.innerWidth - 32)) < 1 &&
        use.bottom <= window.innerHeight && use.width >= window.innerWidth - 40 &&
        getComputedStyle(stage).touchAction === 'none';
    })()
    """)

    :ok
  end

  step "I drag the picture up to keep its bottom and use the photo", %{session: session} do
    window =
      Fluffy.Playwright.bounding_box(session, by_css("#group-cover-upload-crop .crop-window"))

    x = window.x + window.width / 2
    top = window.y + 4
    bottom = window.y + window.height - 4

    # Three drags from the bottom of the window to its top; the picture
    # stops at its own bottom edge, whatever it was dragged past.
    for _ <- 1..3 do
      session
      |> Mouse.move(x, bottom)
      |> Mouse.down()
      |> Mouse.move(x, top, steps: 6)
      |> Mouse.up()
    end

    session
    |> assert_browser("""
    (() => {
      const sheet = document.querySelector('#group-cover-upload-crop');
      const pic = sheet.querySelector('.crop-pic').getBoundingClientRect();
      const win = sheet.querySelector('.crop-window').getBoundingClientRect();
      return Math.abs(pic.bottom - win.bottom) < 1;
    })()
    """)
    |> assert(visible(by_role(:button, name: "Reset")))
    |> click(by_role(:button, name: "Use photo"))

    :ok
  end

  step "the slot uploads a 16:9 cover showing only the bottom of my picture",
       %{session: session} do
    cover =
      by_css("#group-cover-upload[data-state=uploaded] .cover-slot img[src*='group_images']")

    session
    |> refute(visible(by_css("#group-cover-upload-crop[open]")))
    |> assert(visible(cover))

    thumbnail_path = get_attribute(session, cover, "src")

    image =
      Huddlz.Communities.GroupImage
      |> Ash.Query.filter(thumbnail_path == ^thumbnail_path)
      |> Ash.read_one!(authorize?: false)

    assert String.ends_with?(image.filename, ".jpg")
    assert image.content_type == "image/jpeg"

    # The upload itself is the crop: 16:9, and nothing but the blue half.
    {:ok, uploaded} = Image.open(Path.join("priv/static", image.storage_path))
    width = Image.width(uploaded)
    height = Image.height(uploaded)
    assert_in_delta width / height, 16 / 9, 0.01
    assert width == 600

    for {x, y} <- [{4, 4}, {width - 5, 4}, {4, height - 5}, {width - 5, height - 5}] do
      assert {:ok, [r, _g, b | _]} = Image.get_pixel(uploaded, x, y)
      assert r < 90 and b > 180, "expected blue at #{x},#{y}, got #{inspect({r, b})}"
    end

    :ok
  end
end
