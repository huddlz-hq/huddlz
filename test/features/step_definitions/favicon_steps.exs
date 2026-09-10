defmodule FaviconSteps do
  use Cucumber.StepDefinition

  import ExUnit.Assertions
  import ExUnit.Callbacks, only: [on_exit: 1]
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
    Map.put(context, :svg, response.resp_body)
  end

  step "it is a cyan rounded square with a dark \"h\" and no glow effects", context do
    {:ok, actual} = Image.from_binary(context.svg)
    {:ok, reference} = Image.open("test/fixtures/brand-mark.png")
    {:ok, difference, _image} = Image.compare(actual, reference, metric: :rmse)

    # Allow small rasterizer/antialiasing differences, while checking the visible
    # glyph, placement, colors and tile instead of how the SVG is constructed.
    assert difference < 0.01, "favicon differs from the brand mark (RMSE #{difference})"
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

  step "a browser fetches an icon by its cache-busting name", context do
    # Once the assets are digested, `~p` stamps a content hash into the name of
    # every static file it knows about, so the endpoint has to serve the stamped
    # name too. Nothing is digested under test, so stand one in by hand.
    stamped = "favicon-#{String.duplicate("0", 32)}.svg"
    root = Application.app_dir(:huddlz, "priv/static")

    File.cp!(Path.join(root, "favicon.svg"), Path.join(root, stamped))
    on_exit(fn -> File.rm(Path.join(root, stamped)) end)

    Map.put(context, :response, get(build_conn(), "/#{stamped}?vsn=d"))
  end

  step "the icon is served", context do
    assert context.response.status == 200
    assert response_content_type(context.response, :svg) =~ "image/svg+xml"
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
