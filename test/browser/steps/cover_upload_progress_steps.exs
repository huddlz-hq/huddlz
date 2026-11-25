defmodule BrowserCoverUploadSteps do
  use Cucumber.StepDefinition
  use Fluffy.Assert

  import Fluffy, except: [step: 3]
  import Fluffy.Locator
  import Huddlz.Generator
  import Huddlz.Test.BrowserHelpers

  alias Huddlz.Storage.GroupImages

  step "I am creating a group in a browser where preparing a cover takes a moment",
       %{session: session} do
    owner = generate(user(role: :user))

    # Preparing the cover normally takes a few hundred milliseconds; hold it
    # for a moment so the in-progress state is there to be observed.
    Application.put_env(:huddlz, :image_storage_overrides, %{
      GroupImages => Huddlz.Test.SlowGroupImages
    })

    ExUnit.Callbacks.on_exit(fn ->
      Application.delete_env(:huddlz, :image_storage_overrides)
      File.rm_rf!("priv/static/uploads/group_images/pending")
    end)

    # Remember where the slot and the name field sit before anything happens.
    session
    |> sign_in(owner)
    |> visit("/groups/new")
    |> assert(visible(by_css("#group-cover-upload[data-state=idle]")))
    |> assert_browser("""
    (() => {
      const slot = document.querySelector('#group-cover-upload .cover-slot').getBoundingClientRect();
      const name = document.querySelector('#group-form input[name="form[name]"]').getBoundingClientRect();
      window.__coverBefore = {slot: [slot.top, slot.height, slot.width], name: [name.top, name.height]};
      return slot.height > 100 && Math.abs(slot.width / slot.height - 16 / 9) < 0.02;
    })()
    """)

    :ok
  end

  step "I choose a picture for the cover", %{session: session} do
    # The crop sheet opens first; the picture already fits, so use it as is.
    session
    |> set_input_files(by_label("Cover image", exact: true), "test/fixtures/test_image.jpg")
    |> assert(visible(by_css("#group-cover-upload-crop[open]")))
    |> click(by_role(:button, name: "Use photo"))

    :ok
  end

  step "the slot shows my picture with the upload in progress and the form is still usable",
       %{session: session} do
    session
    |> assert_browser("""
    (() => {
      const root = document.querySelector('#group-cover-upload');
      if (!root || root.dataset.state !== 'uploading') return false;
      const img = root.querySelector('.cover-slot img');
      const bar = root.querySelector('.cover-slot-bar');
      const slot = root.querySelector('.cover-slot').getBoundingClientRect();
      const name = document.querySelector('#group-form input[name="form[name]"]');
      const before = window.__coverBefore;
      return img && img.src.startsWith('blob:') && img.complete && img.naturalWidth > 0 &&
        bar && bar.getBoundingClientRect().bottom <= slot.bottom + 1 &&
        Math.abs(slot.top - before.slot[0]) < 1 && Math.abs(slot.height - before.slot[1]) < 1 &&
        !name.disabled && !document.querySelector('#group-form [disabled]') &&
        Math.abs(name.getBoundingClientRect().top - before.name[0]) < 1;
    })()
    """)
    # Typing while the cover is prepared must work.
    |> fill(by_label("Group name", exact: true), "Typed while uploading")
    |> assert(visible(by_css("#group-cover-upload[data-state=uploading]")))

    :ok
  end

  step "the slot settles on the prepared cover without moving", %{session: session} do
    session
    |> assert(
      visible(
        by_css("#group-cover-upload[data-state=uploaded] .cover-slot img[src*='group_images']")
      )
    )
    |> assert_browser("""
    (() => {
      const root = document.querySelector('#group-cover-upload');
      const img = root.querySelector('.cover-slot img');
      const slot = root.querySelector('.cover-slot').getBoundingClientRect();
      const before = window.__coverBefore;
      return img.complete && img.naturalWidth > 0 &&
        Math.abs(slot.top - before.slot[0]) < 1 && Math.abs(slot.height - before.slot[1]) < 1 &&
        !root.querySelector('.cover-slot-bar') &&
        document.querySelector('#group-form input[name="form[name]"]').value === 'Typed while uploading';
    })()
    """)

    :ok
  end
end
