defmodule BrowserCoverSteps do
  use Cucumber.StepDefinition
  use Fluffy.Assert

  import Fluffy, except: [step: 3]
  import Fluffy.Locator
  import Huddlz.Generator
  import Huddlz.Test.BrowserHelpers

  alias Huddlz.Storage.Local

  step "a group with long details and a {string} cover", %{args: [state]} do
    owner = generate(user(role: :user))

    group =
      generate(
        group(
          name: "The remarkably long community name for neighbors who enjoy learning together",
          location:
            "123 AReallyLongUnbrokenStreetNameToExerciseWrapping, Saint Augustine, Florida, USA",
          owner_id: owner.id,
          is_public: true,
          actor: owner
        )
      )

    ExUnit.Callbacks.on_exit(fn ->
      File.rm_rf!("priv/static/uploads/group_images/#{group.id}")
    end)

    path = "/uploads/group_images/#{group.id}/browser-cover.jpg"

    if state == "valid",
      do: assert({:ok, ^path} = Local.put("test/fixtures/test_image.jpg", path, "image/jpeg"))

    if state != "missing" do
      Huddlz.Communities.create_group_image!(
        %{
          filename: "browser-cover.jpg",
          content_type: "image/jpeg",
          size_bytes: File.stat!("test/fixtures/test_image.jpg").size,
          storage_path: path,
          thumbnail_path: path,
          group_id: group.id
        },
        actor: owner
      )
    end

    %{group: group, cover_state: state}
  end

  step "I open that group in the browser", %{session: session} = context do
    session
    |> visit("/groups/#{context.group.slug}")
    |> assert(visible(by_role(:heading, level: 1, name: to_string(context.group.name))))

    :ok
  end

  step "its cover has the expected image or visible fallback", %{session: session} = context do
    assert_cover(session, context.cover_state)
    :ok
  end

  step "its title and location fit without clipping or horizontal overflow",
       %{session: session} do
    assert_browser(session, """
    (() => {
      const hero = document.querySelector('#group-detail-hero');
      const bounds = hero.getBoundingClientRect();
      return document.documentElement.scrollWidth <= innerWidth &&
        [...hero.querySelectorAll('h1, .group-hero-location')].every(element => {
          const rect = element.getBoundingClientRect();
          return rect.width > 0 && rect.height > 0 && rect.left >= bounds.left &&
            rect.right <= bounds.right + 1 && rect.top >= bounds.top && rect.bottom <= bounds.bottom + 1 &&
            element.scrollWidth <= element.clientWidth + 1 &&
            (getComputedStyle(element).overflowY === 'visible' || element.scrollHeight <= element.clientHeight + 1);
        });
    })()
    """)

    :ok
  end

  step "the mobile cover stays above the group details", %{session: session} do
    assert_browser(session, """
    (() => {
      const cover = document.querySelector('#group-detail-hero .group-cover').getBoundingClientRect();
      const details = document.querySelector('#group-detail-hero .hero-content').getBoundingClientRect();
      return cover.height > 100 && cover.bottom <= details.top + 1;
    })()
    """)

    :ok
  end

  step "the group sidebar aligns with the top of the cover", %{session: session} do
    assert_browser(session, """
    (() => {
      const cover = document.querySelector('#group-detail-hero .group-cover').getBoundingClientRect();
      const sidebar = document.querySelector('.huddl-side').getBoundingClientRect();
      return sidebar.left >= cover.right && Math.abs(sidebar.top - cover.top) <= 1;
    })()
    """)

    :ok
  end

  defp assert_cover(session, "missing") do
    session
    |> refute(visible(cover_image()))
    |> assert_fallback()
  end

  defp assert_cover(session, state) do
    assert(session, visible(cover_image()))

    decoded =
      Fluffy.Playwright.evaluate(session, """
      (async () => {
        const element = document.querySelector('#group-detail-hero .cover-image');
        const url = getComputedStyle(element).backgroundImage.slice(5, -2);
        const image = new Image();
        image.src = url;
        try { await image.decode(); return image.naturalWidth > 0; }
        catch { return false; }
      })()
      """)

    assert decoded == (state == "valid")

    outcome = if state == "valid", do: "loaded", else: "failed"

    session
    |> assert(attribute(cover_image(), "data-cover-state", outcome))
    |> refute(contain_class(cover_image(), "is-pending"))

    if state == "failed", do: assert_fallback(session), else: assert_painted_cover(session)
  end

  defp cover_image, do: by_css("#group-detail-hero .cover-image")

  defp assert_painted_cover(session) do
    assert_browser(session, """
    (() => {
      const cover = document.querySelector('#group-detail-hero .group-cover');
      const layer = cover.querySelector('.cover-image');
      const fallback = cover.querySelector('.group-cover-fallback');
      const style = getComputedStyle(layer);
      const bounds = cover.getBoundingClientRect();
      const imageBounds = layer.getBoundingClientRect();
      const layerOrder = Number(style.zIndex) || 0;
      const fallbackOrder = Number(getComputedStyle(fallback).zIndex) || 0;
      const aboveFallback = layerOrder > fallbackOrder ||
        (layerOrder === fallbackOrder && (fallback.compareDocumentPosition(layer) & Node.DOCUMENT_POSITION_FOLLOWING));
      return style.opacity === '1' && getComputedStyle(cover).opacity === '1' &&
        style.visibility === 'visible' && aboveFallback && imageBounds.width > 0 &&
        imageBounds.width >= bounds.width - 1 && imageBounds.height >= bounds.height - 1;
    })()
    """)
  end

  defp assert_fallback(session) do
    session
    |> assert(visible(by_css("#group-detail-hero .group-cover-signal")))
    |> assert_browser("""
    (() => {
      const cover = document.querySelector('#group-detail-hero .group-cover');
      const fallback = cover.querySelector('.group-cover-fallback');
      const image = cover.querySelector('.cover-image');
      return getComputedStyle(cover).backgroundColor !== 'rgba(0, 0, 0, 0)' &&
        fallback.getBoundingClientRect().height > 0 && getComputedStyle(fallback).visibility === 'visible' &&
        (!image || getComputedStyle(image).backgroundColor === 'rgba(0, 0, 0, 0)');
    })()
    """)
  end
end
