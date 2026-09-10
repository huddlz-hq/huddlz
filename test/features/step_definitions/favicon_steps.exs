defmodule FaviconSteps do
  use Cucumber.StepDefinition

  import ExUnit.Assertions
  import Phoenix.ConnTest

  @endpoint HuddlzWeb.Endpoint

  step "a browser fetches the home page", context do
    Map.put(context, :page_html, build_conn() |> get("/") |> html_response(200))
  end

  step "the page links an SVG favicon, an apple touch icon and a fallback ICO", context do
    links = icon_links(context.page_html)

    assert {"icon", "/favicon.svg", "image/svg+xml", _} = find_link(links, "/favicon.svg")

    assert {"apple-touch-icon", "/apple-touch-icon.png", _, "180x180"} =
             find_link(links, "/apple-touch-icon.png")

    assert {"alternate icon", "/favicon.ico", _, sizes} = find_link(links, "/favicon.ico")
    assert sizes =~ "16x16"
    context
  end

  step "a browser fetches the SVG favicon", context do
    response = get(build_conn(), "/favicon.svg")
    assert response.status == 200
    assert response_content_type(response, :svg) =~ "image/svg+xml"
    Map.put(context, :svg, Floki.parse_fragment!(response.resp_body))
  end

  step "it is a cyan rounded square with a dark \"h\" and no glow effects", context do
    svg = context.svg

    [tile] = Floki.find(svg, "rect")
    assert Floki.attribute([tile], "fill") == ["#18cbd4"]
    assert [rx] = Floki.attribute([tile], "rx")
    assert String.to_integer(rx) > 0
    assert Floki.attribute([tile], "stroke") == []

    glyphs = Floki.find(svg, "path")
    assert glyphs != []
    assert Enum.all?(glyphs, &(Floki.attribute([&1], "stroke") == ["#05191b"]))

    assert Floki.find(svg, "filter, feGaussianBlur, feDropShadow") == []
    context
  end

  step "a browser fetches each linked icon", context do
    fetched =
      for {_rel, href, _type, sizes} <- icon_links(context.page_html) do
        {href, sizes, get(build_conn(), href)}
      end

    Map.put(context, :icons, fetched)
  end

  step "each is served as an image of the size it is linked as", context do
    for {href, sizes, response} <- context.icons do
      assert response.status == 200, "#{href} was not served"
      expected = sizes |> to_string() |> String.split() |> Enum.map(&parse_size/1)
      assert served_sizes(href, response.resp_body) == expected, "#{href} sizes"
    end

    context
  end

  # A PNG carries one size; an ICO a directory of them; an SVG scales.
  defp served_sizes(href, body) do
    case Path.extname(href) do
      ".svg" ->
        []

      ".png" ->
        {:ok, image} = Image.from_binary(body)
        [{Image.width(image), Image.height(image)}]

      ".ico" ->
        <<0::16-little, 1::16-little, count::16-little, rest::binary>> = body

        for <<w, h, _entry::binary-size(14) <- binary_part(rest, 0, count * 16)>> do
          {ico_dim(w), ico_dim(h)}
        end
    end
  end

  defp ico_dim(0), do: 256
  defp ico_dim(n), do: n

  defp parse_size("any"), do: :any

  defp parse_size(size) do
    [w, h] = size |> String.split("x") |> Enum.map(&String.to_integer/1)
    {w, h}
  end

  defp icon_links(html) do
    html
    |> Floki.parse_document!()
    |> Floki.find("link[rel$='icon']")
    |> Enum.map(fn link ->
      {attr(link, "rel"), attr(link, "href"), attr(link, "type"), attr(link, "sizes")}
    end)
  end

  defp find_link(links, href), do: Enum.find(links, &(elem(&1, 1) == href))

  defp attr(node, name), do: node |> Floki.attribute(name) |> List.first()
end
