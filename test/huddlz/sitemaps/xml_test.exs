defmodule Huddlz.Sitemaps.XMLTest do
  use ExUnit.Case, async: true
  alias Huddlz.Sitemaps.XML
  @moduletag :sitemap

  test "the 50,000 URL protocol limit cannot be raised by configuration" do
    pages =
      Stream.map(1..50_001, &{"https://huddlz.test/groups/group-#{&1}", ~U[2026-08-01 10:30:00Z]})

    [first, second] = Enum.to_list(XML.urlsets(pages, max_urls: 100_000))
    assert length(Regex.scan(~r/<url>/, first)) == 50_000
    assert length(Regex.scan(~r/<url>/, second)) == 1
    assert second =~ "/groups/group-50001</loc>"
    assert byte_size(first) < 52_428_800
  end

  test "the 50 MB uncompressed limit wins before the URL count limit" do
    loc = "https://huddlz.test/groups/" <> String.duplicate("a", 1_950)
    pages = Stream.map(1..30_000, fn _ -> {loc, ~U[2026-08-01 10:30:00Z]} end)
    documents = Enum.to_list(XML.urlsets(pages, max_urls: 50_000, max_bytes: 100_000_000))
    assert length(documents) == 2
    assert Enum.all?(documents, &(byte_size(&1) <= 52_428_800))
    assert Enum.sum(Enum.map(documents, &length(Regex.scan(~r/<url>/, &1)))) == 30_000
  end

  test "XML escapes URL data and preserves real modification times" do
    [xml] =
      Enum.to_list(
        XML.urlsets([{"https://huddlz.test/groups/a?one=1&two=2", ~U[2026-08-01 10:30:00Z]}])
      )

    {doc, []} = :xmerl_scan.string(String.to_charlist(xml), quiet: true)
    [text] = :xmerl_xpath.string(~c"//url/loc/text()", doc)
    assert text |> elem(4) |> to_string() == "https://huddlz.test/groups/a?one=1&two=2"
    assert xml =~ "<lastmod>2026-08-01T10:30:00Z</lastmod>"
    assert xml =~ "xmlns=\"http://www.sitemaps.org/schemas/sitemap/0.9\""
  end

  test "the index is bounded and rejects excess children" do
    assert_raise ArgumentError, "Sitemap index exceeds protocol limits", fn ->
      XML.index(Stream.map(1..50_001, &"https://huddlz.test/sitemap-#{&1}.xml"))
    end
  end
end
