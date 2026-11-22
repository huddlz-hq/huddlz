defmodule BrowserCoverCropSteps do
  use Cucumber.StepDefinition

  import ExUnit.Assertions
  import Huddlz.Generator
  import Huddlz.Test.BrowserHelpers
  import PhoenixTest

  require Ash.Query

  alias PlaywrightEx.Frame
  alias PlaywrightEx.Page

  step "I am creating a group in a browser", context do
    owner = generate(user(role: :user))

    ExUnit.Callbacks.on_exit(fn ->
      File.rm_rf!("priv/static/uploads/group_images/pending")
    end)

    conn =
      context.conn
      |> sign_in(owner)
      |> visit("/groups/new")
      |> assert_has(".phx-connected")
      |> assert_has("#group-cover-upload[data-state=idle]")

    Map.put(context, :conn, conn)
  end

  step "I choose a tall picture for the cover", context do
    assert {:ok, _} =
             Frame.set_input_files(context.conn.frame_id,
               selector: "#group-cover-upload input[type=file]",
               timeout: 5_000,
               local_paths: [Path.expand("test/fixtures/tall_red_blue.png")]
             )

    context
  end

  step "the crop sheet opens with the picture fit to the 16:9 window", context do
    assert_browser(context.conn, """
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

    context
  end

  step "the crop sheet fills the screen with the window and Use photo in view", context do
    assert_browser(context.conn, """
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

    context
  end

  step "I drag the picture up to keep its bottom and use the photo", context do
    conn = context.conn

    {:ok, %{"x" => x, "top" => top, "bottom" => bottom}} =
      Frame.evaluate(conn.frame_id,
        timeout: 5_000,
        expression: """
        (() => {
          const win = document.querySelector('#group-cover-upload-crop .crop-window').getBoundingClientRect();
          return {x: win.left + win.width / 2, top: win.top + 4, bottom: win.bottom - 4};
        })()
        """
      )

    # Three drags from the bottom of the window to its top; the picture
    # stops at its own bottom edge, whatever it was dragged past.
    for _ <- 1..3 do
      assert {:ok, _} = Page.mouse_move(conn.page_id, x: x, y: bottom, timeout: 5_000)
      assert {:ok, _} = Page.mouse_down(conn.page_id, timeout: 5_000)
      assert {:ok, _} = Page.mouse_move(conn.page_id, x: x, y: top, steps: 6, timeout: 5_000)
      assert {:ok, _} = Page.mouse_up(conn.page_id, timeout: 5_000)
    end

    conn =
      conn
      |> assert_browser("""
      (() => {
        const sheet = document.querySelector('#group-cover-upload-crop');
        const pic = sheet.querySelector('.crop-pic').getBoundingClientRect();
        const win = sheet.querySelector('.crop-window').getBoundingClientRect();
        return Math.abs(pic.bottom - win.bottom) < 1 && !sheet.querySelector('[data-crop-reset]').hidden;
      })()
      """)
      |> click_button("Use photo")

    Map.put(context, :conn, conn)
  end

  step "the slot uploads a 16:9 cover showing only the bottom of my picture", context do
    conn =
      context.conn
      |> refute_has("#group-cover-upload-crop[open]")
      |> assert_has(
        "#group-cover-upload[data-state=uploaded] .cover-slot img[src*='group_images']"
      )

    {:ok, thumbnail_path} =
      Frame.evaluate(conn.frame_id,
        timeout: 5_000,
        expression:
          "document.querySelector('#group-cover-upload .cover-slot img').getAttribute('src')"
      )

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

    Map.put(context, :conn, conn)
  end
end
