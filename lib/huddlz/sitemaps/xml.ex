defmodule Huddlz.Sitemaps.XML do
  @moduledoc "Streams bounded sitemap XML documents from canonical URL/content-time pairs."
  @namespace "http://www.sitemaps.org/schemas/sitemap/0.9"
  @max_count 50_000
  @max_bytes 52_428_800

  def urlsets(pages, opts \\ []) do
    count = limit!(opts, :max_urls, 5_000, @max_count)
    bytes = limit!(opts, :max_bytes, @max_bytes, @max_bytes)
    envelope = byte_size(document("urlset", []))

    pages
    |> Stream.map(fn {loc, lastmod} ->
      "<url><loc>#{location!(loc)}</loc><lastmod>#{DateTime.to_iso8601(lastmod)}</lastmod></url>"
    end)
    |> Stream.chunk_while(
      {[], 0, envelope},
      fn entry, {entries, total, size} ->
        cond do
          byte_size(entry) + envelope > bytes ->
            raise ArgumentError, "Sitemap entry exceeds byte limit"

          total > 0 and (total >= count or size + byte_size(entry) > bytes) ->
            {:cont, Enum.reverse(entries), {[entry], 1, envelope + byte_size(entry)}}

          true ->
            {:cont, {[entry | entries], total + 1, size + byte_size(entry)}}
        end
      end,
      fn
        {[], _, _} -> {:cont, []}
        {entries, _, _} -> {:cont, Enum.reverse(entries), []}
      end
    )
    |> Stream.map(&document("urlset", &1))
  end

  def index(locations) do
    envelope = byte_size(document("sitemapindex", []))

    {entries, _, _} =
      Enum.reduce(locations, {[], 0, envelope}, fn loc, {entries, count, size} ->
        entry = "<sitemap><loc>#{location!(loc)}</loc></sitemap>"

        if count >= @max_count or size + byte_size(entry) > @max_bytes,
          do: raise(ArgumentError, "Sitemap index exceeds protocol limits")

        {[entry | entries], count + 1, size + byte_size(entry)}
      end)

    case entries do
      [] -> ""
      _ -> document("sitemapindex", Enum.reverse(entries))
    end
  end

  defp location!(loc) do
    if String.length(loc) >= 2_048, do: raise(ArgumentError, "Sitemap URL exceeds protocol limit")
    loc |> Phoenix.HTML.html_escape() |> Phoenix.HTML.safe_to_string()
  end

  defp limit!(opts, key, default, maximum) do
    case Keyword.get(opts, key, default) do
      n when is_integer(n) and n > 0 -> min(n, maximum)
      _ -> raise ArgumentError, "#{key} must be a positive integer"
    end
  end

  defp document(tag, entries) do
    IO.iodata_to_binary([
      "<?xml version=\"1.0\" encoding=\"UTF-8\"?><",
      tag,
      " xmlns=\"",
      @namespace,
      "\">",
      entries,
      "</",
      tag,
      ">"
    ])
  end
end
