defmodule HuddlzWeb.Components.CoverImageTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest
  import HuddlzWeb.Components.CoverImage

  test "renders decorative CSS media revealed by the cover hook" do
    html =
      render_component(&cover_image/1,
        id: "cover",
        image_url: "/uploads/cover.png",
        class: "hero-img"
      )

    document = Floki.parse_fragment!(html)

    assert Floki.find(document, "#cover.cover-image[aria-hidden='true']") != []

    assert Floki.attribute(document, "#cover", "style") == [
             ~s|background-image: url("/uploads/cover.png")|
           ]

    assert Floki.find(
             document,
             ~s|#cover[phx-hook="CoverImage"][data-cover-url="/uploads/cover.png"]|
           ) != []

    assert Floki.find(document, "img, [onerror], [onload]") == []
  end

  test "escapes CSS string delimiters without double-encoding a URL" do
    path = ~s(/uploads/a%20b"\\cover.png?size=large&v=2)
    html = render_component(&cover_image/1, id: "cover", image_url: path, class: "hero-img")
    document = Floki.parse_fragment!(html)

    assert Floki.attribute(document, "#cover", "style") ==
             [~s|background-image: url("/uploads/a%20b%22%5Ccover.png?size=large&v=2")|]
  end
end
