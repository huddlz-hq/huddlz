defmodule BrowserCoverSteps do
  use Cucumber.StepDefinition

  import ExUnit.Assertions
  import Huddlz.Generator
  import Huddlz.Test.BrowserHelpers
  import PhoenixTest
  import PhoenixTest.Playwright, only: [evaluate: 3]

  alias Huddlz.Storage.Local

  step "a group with long details and a {string} cover", %{args: [state]} = context do
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

    ExUnit.Callbacks.on_exit(fn ->
      File.rm_rf!("priv/static/uploads/group_images/#{group.id}")
    end)

    Map.merge(context, %{group: group, cover_state: state})
  end

  step "I open that group in the browser", context do
    conn =
      context.conn
      |> visit("/groups/#{context.group.slug}")
      |> assert_has(".phx-connected")
      |> assert_has("h1", text: context.group.name)

    Map.put(context, :conn, conn)
  end

  step "its cover has the expected image or visible fallback", context do
    assert_cover(context.conn, context.cover_state)
    context
  end

  step "its title and location fit without clipping or horizontal overflow", context do
    assert_browser(context.conn, """
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

    context
  end

  step "the mobile cover stays above the group details", context do
    assert_browser(context.conn, """
    (() => {
      const cover = document.querySelector('#group-detail-hero .group-cover').getBoundingClientRect();
      const details = document.querySelector('#group-detail-hero .hero-content').getBoundingClientRect();
      return cover.height > 100 && cover.bottom <= details.top + 1;
    })()
    """)

    context
  end

  defp assert_cover(conn, "missing") do
    conn
    |> refute_has("#group-detail-hero .cover-image")
    |> assert_fallback()
  end

  defp assert_cover(conn, state) do
    conn = assert_has(conn, "#group-detail-hero .cover-image")

    evaluate(
      conn,
      """
      (async () => {
        const element = document.querySelector('#group-detail-hero .cover-image');
        const url = getComputedStyle(element).backgroundImage.slice(5, -2);
        const image = new Image();
        image.src = url;
        try { await image.decode(); return image.naturalWidth > 0; }
        catch { return false; }
      })()
      """,
      fn decoded -> assert decoded == (state == "valid") end
    )

    if state == "failed", do: assert_fallback(conn), else: conn
  end

  defp assert_fallback(conn) do
    conn
    |> assert_has("#group-detail-hero .group-cover-label", text: "huddlz group")
    |> assert_browser("""
    (() => {
      const cover = document.querySelector('#group-detail-hero .group-cover');
      const fallback = cover.querySelector('.group-cover-fallback');
      const image = cover.querySelector('.cover-image');
      return getComputedStyle(cover).backgroundImage.includes('gradient') &&
        fallback.getBoundingClientRect().height > 0 && getComputedStyle(fallback).visibility === 'visible' &&
        (!image || getComputedStyle(image).backgroundColor === 'rgba(0, 0, 0, 0)');
    })()
    """)
  end
end
