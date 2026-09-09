defmodule HuddlzWeb.SitemapControllerTest do
  use HuddlzWeb.ConnCase, async: true
  @moduletag :sitemap
  alias Huddlz.Sitemaps

  test "robots advertises the configured sitemap and the scheduler refreshes it" do
    conn = get(build_conn(), "/robots.txt")
    assert response(conn, 200) =~ "Sitemap: #{HuddlzWeb.Endpoint.url()}/sitemap.xml"
    assert response_content_type(conn, :text)

    config =
      AshOban.config(
        Application.fetch_env!(:huddlz, :ash_domains),
        Application.fetch_env!(:huddlz, Oban)
      )

    {_, cron} = Enum.find(config[:plugins], fn {module, _} -> module == Oban.Plugins.Cron end)
    assert {"*/15 * * * *", Huddlz.Sitemaps.Refresh} in cron[:crontab]
  end

  test "an ungenerated index asks crawlers to retry without starting a scan" do
    conn = get(build_conn(), "/sitemap.xml")
    assert response(conn, 503) =~ "prepared"
    assert get_resp_header(conn, "retry-after") == ["900"]
    assert get_resp_header(conn, "cache-control") == ["no-store"]
  end

  test "lastmod changes for content edits but not reminder delivery" do
    host = generate(user())
    group = generate(group(actor: host, is_public: true))
    huddl = generate(huddl(group_id: group.id, actor: host, is_private: false))
    assert {:ok, :ok} = Sitemaps.refresh()
    before = sitemap_entries()
    loc = "#{HuddlzWeb.Endpoint.url()}/groups/#{group.slug}/huddlz/#{huddl.id}"
    original = Map.fetch!(before, loc)

    group
    |> Ash.Changeset.for_update(:update_details, %{name: to_string(group.name)}, actor: host)
    |> Ash.update!()

    assert {:ok, :ok} = Sitemaps.refresh()
    assert sitemap_entries() == before

    huddl = huddl |> Ash.Changeset.for_update(:send_24h_reminder, %{}) |> Ash.update!()
    assert {:ok, :ok} = Sitemaps.refresh()
    assert sitemap_entries()[loc] == original

    huddl = Ash.get!(Huddlz.Communities.Huddl, huddl.id, actor: host)

    edited =
      huddl
      |> Ash.Changeset.for_update(:update, %{title: "Revised public title"}, actor: host)
      |> Ash.update!()

    assert {:ok, :ok} = Sitemaps.refresh()
    assert sitemap_entries()[loc] == DateTime.to_iso8601(edited.updated_at)
    refute sitemap_entries()[loc] == original
  end

  test "private pages and drafts stay out; public cancellations and completed pages remain" do
    host = generate(user())
    group = generate(group(actor: host, is_public: true))
    public = generate(huddl(group_id: group.id, actor: host, is_private: false))
    private = generate(huddl(group_id: group.id, actor: host, is_private: true))
    draft = generate(huddl(group_id: group.id, actor: host, lifecycle_state: :draft))

    past =
      generate(past_huddl(group_id: group.id, creator_id: host.id, lifecycle_state: :completed))

    assert {:ok, :ok} = Sitemaps.refresh()
    entries = sitemap_entries()
    assert map_size(entries) == 3
    assert Map.has_key?(entries, huddl_url(group, past))
    refute Map.has_key?(entries, huddl_url(group, private))
    refute Map.has_key?(entries, huddl_url(group, draft))

    for loc <- Map.keys(entries) do
      html = build_conn() |> get(URI.parse(loc).path) |> html_response(200)
      assert Floki.attribute(Floki.parse_document!(html), "link[rel=canonical]", "href") == [loc]

      assert Floki.attribute(Floki.parse_document!(html), "meta[property='og:url']", "content") ==
               [loc]
    end

    draft = draft |> Ash.Changeset.for_update(:publish, %{}, actor: host) |> Ash.update!()
    assert {:ok, :ok} = Sitemaps.refresh()
    assert Map.has_key?(sitemap_entries(), huddl_url(group, draft))
    public |> Ash.Changeset.for_update(:cancel, %{}, actor: host) |> Ash.update!()
    assert build_conn() |> get(URI.parse(huddl_url(group, public)).path) |> html_response(200)
    assert {:ok, :ok} = Sitemaps.refresh()
    assert Map.has_key?(sitemap_entries(), huddl_url(group, public))

    group =
      group
      |> Ash.Changeset.for_update(:update_details, %{is_public: false}, actor: host)
      |> Ash.update!()

    assert_error_sent 404, fn -> get(build_conn(), "/groups/#{group.slug}") end
    assert_error_sent 404, fn -> get(build_conn(), URI.parse(huddl_url(group, draft)).path) end
    assert {:ok, :ok} = Sitemaps.refresh()
    assert sitemap_entries() == %{}
  end

  test "cached files survive refresh while removals disappear from the new index" do
    host = generate(user())
    group = generate(group(actor: host, is_public: true))
    huddl = generate(huddl(group_id: group.id, actor: host, is_private: false))
    assert {:ok, :ok} = Sitemaps.refresh()
    index_conn = get(build_conn(), "/sitemap.xml")
    old_index = response(index_conn, 200)

    old_child =
      old_index
      |> xml_values(~c"//sitemap/loc/text()")
      |> Enum.find(fn child ->
        build_conn() |> get(URI.parse(child).path) |> response(200) =~ huddl.id
      end)

    old_body = build_conn() |> get(URI.parse(old_child).path) |> response(200)
    [etag] = get_resp_header(index_conn, "etag")
    assert get_resp_header(index_conn, "cache-control") == ["public, max-age=300"]

    assert build_conn()
           |> put_req_header("if-none-match", etag)
           |> get("/sitemap.xml")
           |> response(304) == ""

    huddl = huddl |> Ash.Changeset.for_update(:cancel, %{}, actor: host) |> Ash.update!()
    Ash.destroy!(huddl, actor: generate(user(role: :admin)))
    assert_error_sent 404, fn -> get(build_conn(), URI.parse(huddl_url(group, huddl)).path) end
    assert build_conn() |> get("/sitemap.xml") |> response(200) == old_index
    assert {:ok, :ok} = Sitemaps.refresh()
    refute Map.has_key?(sitemap_entries(), huddl_url(group, huddl))
    assert build_conn() |> get(URI.parse(old_child).path) |> response(200) == old_body
    assert build_conn() |> get("/sitemap-missing.xml") |> response(404) == "Not found"
  end

  test "generation splits across database batches without duplicate or missing URLs" do
    host = generate(user())
    group = generate(group(actor: host, is_public: true))
    huddl = generate(huddl(group_id: group.id, actor: host, is_private: false))
    # Clone only persisted row data: a representative larger catalog without
    # thousands of users, memberships, notification jobs or image fixtures.
    Huddlz.Repo.query!(
      """
      INSERT INTO huddlz
      SELECT (jsonb_populate_record(NULL::huddlz,
        to_jsonb(h) || jsonb_build_object('id', gen_random_uuid()))).*
      FROM huddlz h CROSS JOIN generate_series(1, 1100)
      WHERE h.id = $1
      """,
      [Ecto.UUID.dump!(huddl.id)]
    )

    assert {:ok, :ok} = Sitemaps.refresh(max_urls: 117)
    index = build_conn() |> get("/sitemap.xml") |> response(200)
    children = xml_values(index, ~c"//sitemap/loc/text()")
    assert length(children) >= 10

    entries =
      Enum.flat_map(children, fn child ->
        conn = get(build_conn(), URI.parse(child).path)
        assert response_content_type(conn, :xml)
        assert get_resp_header(conn, "x-content-type-options") == ["nosniff"]
        body = response(conn, 200)
        assert byte_size(body) <= 52_428_800
        urls = xml_values(body, ~c"//url/loc/text()")
        assert length(urls) <= 117
        urls
      end)

    assert length(entries) == 1102
    assert length(Enum.uniq(entries)) == 1102
    assert Enum.count(entries, &String.contains?(&1, "/huddlz/")) == 1101
    assert {:ok, :ok} = Sitemaps.refresh(max_urls: 117)
    assert build_conn() |> get("/sitemap.xml") |> response(200) == index
  end

  test "byte limits split complete XML documents and a failed refresh preserves published files" do
    host = generate(user())

    group =
      generate(
        group(actor: host, is_public: true, name: "Sitemap byte boundary verification group")
      )

    generate(huddl(group_id: group.id, actor: host, is_private: false))
    assert {:ok, :ok} = Sitemaps.refresh(max_bytes: 380)
    index = build_conn() |> get("/sitemap.xml") |> response(200)
    children = xml_values(index, ~c"//sitemap/loc/text()")
    assert length(children) == 2

    for child <- children do
      body = build_conn() |> get(URI.parse(child).path) |> response(200)
      assert byte_size(body) <= 380
      assert length(xml_values(body, ~c"//url/loc/text()")) == 1
    end

    assert_raise ArgumentError, "Sitemap entry exceeds byte limit", fn ->
      Sitemaps.refresh(max_bytes: 140)
    end

    assert build_conn() |> get("/sitemap.xml") |> response(200) == index
  end

  test "cover changes advance lastmod for the group and its huddl artwork fallback" do
    host = generate(user())
    group = generate(group(actor: host, is_public: true))
    huddl = generate(huddl(group_id: group.id, actor: host, is_private: false))
    assert {:ok, :ok} = Sitemaps.refresh()
    original = sitemap_entries()

    image =
      Huddlz.Communities.create_group_image!(
        %{
          filename: "cover.jpg",
          content_type: "image/jpeg",
          size_bytes: 1234,
          storage_path: "groups/#{group.id}/cover.jpg",
          group_id: group.id
        },
        actor: host
      )

    assert {:ok, :ok} = Sitemaps.refresh()
    changed = sitemap_entries()

    for loc <- ["#{HuddlzWeb.Endpoint.url()}/groups/#{group.slug}", huddl_url(group, huddl)] do
      assert changed[loc] > original[loc]
    end

    image |> Ash.Changeset.for_update(:soft_delete, %{}, actor: host) |> Ash.update!()
    assert {:ok, :ok} = Sitemaps.refresh()
    assert sitemap_entries()[huddl_url(group, huddl)] > changed[huddl_url(group, huddl)]
  end

  test "a huddl privacy edit is enforced before refresh and a group slug edit uses the new canonical URL" do
    host = generate(user())
    group = generate(group(actor: host, is_public: true))
    huddl = generate(huddl(group_id: group.id, actor: host, is_private: false))
    assert {:ok, :ok} = Sitemaps.refresh()
    old_loc = huddl_url(group, huddl)

    huddl =
      huddl
      |> Ash.Changeset.for_update(:update, %{is_private: true}, actor: host)
      |> Ash.update!()

    assert_error_sent 404, fn -> get(build_conn(), URI.parse(old_loc).path) end
    assert {:ok, :ok} = Sitemaps.refresh()
    refute Map.has_key?(sitemap_entries(), old_loc)

    huddl =
      huddl
      |> Ash.Changeset.for_update(:update, %{is_private: false}, actor: host)
      |> Ash.update!()

    group =
      group
      |> Ash.Changeset.for_update(:update_details, %{slug: "revised-sitemap-group"}, actor: host)
      |> Ash.update!()

    assert {:ok, :ok} = Sitemaps.refresh()
    entries = sitemap_entries()
    refute Map.has_key?(entries, old_loc)
    assert Map.has_key?(entries, huddl_url(group, huddl))
    assert entries[huddl_url(group, huddl)] == DateTime.to_iso8601(group.updated_at)
    Ash.destroy!(group, actor: host)
    assert_error_sent 404, fn -> get(build_conn(), "/groups/#{group.slug}") end
    assert {:ok, :ok} = Sitemaps.refresh()
    assert sitemap_entries() == %{}
  end

  test "expired historical children are collected while the current index remains resolvable" do
    host = generate(user())
    group = generate(group(actor: host, is_public: true))
    assert {:ok, :ok} = Sitemaps.refresh()
    old_index = build_conn() |> get("/sitemap.xml") |> response(200)
    [old_child] = xml_values(old_index, ~c"//sitemap/loc/text()")

    group
    |> Ash.Changeset.for_update(:update_details, %{description: "Updated public description"},
      actor: host
    )
    |> Ash.update!()

    assert {:ok, :ok} = Sitemaps.refresh()
    # Simulate retention time passing, without waiting two days in a test.
    Huddlz.Repo.query!("UPDATE sitemap_documents SET retained_at = now() - interval '49 hours'")
    assert {:ok, :ok} = Sitemaps.refresh()
    assert build_conn() |> get(URI.parse(old_child).path) |> response(404) == "Not found"
    assert map_size(sitemap_entries()) == 1
  end

  test "a long refresh outage does not break a just-fetched index when generation resumes" do
    host = generate(user())
    group = generate(group(actor: host, is_public: true))
    assert {:ok, :ok} = Sitemaps.refresh()
    index = build_conn() |> get("/sitemap.xml") |> response(200)
    [child] = xml_values(index, ~c"//sitemap/loc/text()")
    Huddlz.Repo.query!("UPDATE sitemap_documents SET retained_at = now() - interval '3 days'")

    group
    |> Ash.Changeset.for_update(:update_details, %{description: "Changed during outage"},
      actor: host
    )
    |> Ash.update!()

    assert {:ok, :ok} = Sitemaps.refresh()
    assert build_conn() |> get(URI.parse(child).path) |> response(200) =~ "<urlset"
  end

  test "renaming and deleting an address book location preserve the copied public content timestamp" do
    host = generate(user())
    group = generate(group(actor: host, is_public: true))
    location = generate(group_location(group_id: group.id, actor: host))

    huddl =
      generate(
        past_huddl(
          group_id: group.id,
          creator_id: host.id,
          group_location_id: location.id,
          lifecycle_state: :completed
        )
      )

    assert {:ok, :ok} = Sitemaps.refresh()
    original = sitemap_entries()[huddl_url(group, huddl)]

    location =
      location
      |> Ash.Changeset.for_update(:update, %{name: "Internal organizer label"}, actor: host)
      |> Ash.update!()

    assert {:ok, :ok} = Sitemaps.refresh()
    assert sitemap_entries()[huddl_url(group, huddl)] == original
    Ash.destroy!(location, actor: host)
    assert {:ok, :ok} = Sitemaps.refresh()
    assert sitemap_entries()[huddl_url(group, huddl)] == original
  end

  test "an empty public catalog returns no content instead of schema-invalid XML" do
    assert {:ok, :ok} = Sitemaps.refresh()
    conn = get(build_conn(), "/sitemap.xml")
    assert response(conn, 204) == ""
    assert get_resp_header(conn, "cache-control") == ["public, max-age=300"]
  end

  defp huddl_url(group, huddl),
    do: "#{HuddlzWeb.Endpoint.url()}/groups/#{group.slug}/huddlz/#{huddl.id}"

  defp sitemap_entries do
    conn = get(build_conn(), "/sitemap.xml")
    index = response(conn, conn.status)
    assert conn.status in [200, 204]

    index
    |> xml_values(~c"//sitemap/loc/text()")
    |> Enum.flat_map(fn loc ->
      xml = build_conn() |> get(URI.parse(loc).path) |> response(200)
      Enum.zip(xml_values(xml, ~c"//url/loc/text()"), xml_values(xml, ~c"//url/lastmod/text()"))
    end)
    |> Map.new()
  end

  defp xml_values("", _path), do: []

  defp xml_values(xml, path) do
    {document, []} = :xmerl_scan.string(String.to_charlist(xml), quiet: true)
    for node <- :xmerl_xpath.string(path, document), do: node |> elem(4) |> to_string()
  end
end
