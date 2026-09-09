defmodule HuddlzWeb.CrawlableLinksTest do
  use HuddlzWeb.ConnCase, async: true
  @moduletag :crawlable_links

  test "anonymous discovery pagination preserves search, date, format and sort", %{conn: conn} do
    owner = generate(user())
    group = generate(group(actor: owner))

    for n <- 1..21 do
      generate(
        past_huddl(
          group_id: group.id,
          creator_id: owner.id,
          title: "Archive crawl #{n}",
          event_type: :virtual,
          latitude: 40.0,
          longitude: -74.0
        )
      )
    end

    params = %{
      "q" => "Archive crawl",
      "date_filter" => "past",
      "event_type" => "virtual",
      "sort" => "newest",
      "lat" => "40.0",
      "lng" => "-74.0",
      "location" => "Test location",
      "time_zone" => "America/New_York",
      "distance" => "25"
    }

    first = document(conn, "/discover?" <> URI.encode_query(params))
    [next] = Floki.attribute(first, "a[aria-label='Next page']", "href")
    assert URI.decode_query(URI.parse(next).query) == Map.put(params, "page", "2")
    second = document(conn, next)
    assert length(Floki.find(first, ".card-title")) == 20
    assert length(Floki.find(second, ".card-title")) == 1
    [previous] = Floki.attribute(second, "a[aria-label='Previous page']", "href")
    assert URI.decode_query(URI.parse(previous).query) == params
    assert Floki.text(document(conn, previous)) =~ "Archive crawl"
    assert Floki.attribute(second, "a[aria-label='Next page']", "href") == []
  end

  test "group discovery links and pagination work without a socket", %{conn: conn} do
    owner = generate(user())
    groups = for n <- 1..21, do: generate(group(actor: owner, name: "Crawl community #{n}"))
    first = document(conn, "/discover?scope=groups&q=Crawl")
    [next] = Floki.attribute(first, "a[aria-label='Next page']", "href")

    assert URI.decode_query(URI.parse(next).query) == %{
             "scope" => "groups",
             "q" => "Crawl",
             "page" => "2"
           }

    second = document(conn, next)
    paths = Floki.attribute(first, "a.card", "href") ++ Floki.attribute(second, "a.card", "href")

    for group <- groups do
      path = "/groups/#{group.slug}"
      assert path in paths
      assert Floki.text(document(conn, path)) =~ to_string(group.name)
    end
  end

  test "public listings exclude private, draft, cancelled and deleted huddlz", %{conn: conn} do
    owner = generate(user())
    group = generate(group(actor: owner))
    private_group = generate(group(actor: owner, is_public: false))
    visible = generate(huddl(group_id: group.id, actor: owner))

    hidden =
      for {target, attrs} <- [
            {group, [is_private: true]},
            {private_group, []},
            {group, [lifecycle_state: :draft]}
          ] do
        generate(huddl([group_id: target.id, actor: owner] ++ attrs))
      end

    cancelled = generate(huddl(group_id: group.id, actor: owner))
    cancelled = cancelled |> Ash.Changeset.for_update(:cancel, %{}, actor: owner) |> Ash.update!()
    deleted = generate(huddl(group_id: group.id, actor: owner))
    deleted = deleted |> Ash.Changeset.for_update(:cancel, %{}, actor: owner) |> Ash.update!()
    Ash.destroy!(deleted, actor: generate(user(role: :admin)))

    for path <- ["/discover", "/discover?date_filter=all", "/groups/#{group.slug}"] do
      links = Floki.attribute(document(conn, path), "a", "href")
      assert "/groups/#{group.slug}/huddlz/#{visible.id}" in links

      for huddl <- [cancelled, deleted | hidden] do
        refute Enum.any?(links, &String.ends_with?(&1, "/huddlz/#{huddl.id}"))
      end
    end

    assert document(conn, "/groups/#{group.slug}/huddlz/#{cancelled.id}")

    for huddl <- [deleted | hidden] do
      slug = if huddl.group_id == group.id, do: group.slug, else: private_group.slug

      assert {404, _, _} =
               assert_error_sent(404, fn -> get(conn, "/groups/#{slug}/huddlz/#{huddl.id}") end)
    end

    refute "/groups/#{private_group.slug}" in Floki.attribute(
             document(conn, "/discover?scope=groups"),
             "a",
             "href"
           )
  end

  test "the public group archive excludes restricted past huddlz", %{conn: conn} do
    owner = generate(user())
    group = generate(group(actor: owner))
    public = generate(past_huddl(group_id: group.id, creator_id: owner.id))

    hidden =
      for attrs <- [[is_private: true], [lifecycle_state: :draft], [lifecycle_state: :cancelled]] do
        generate(past_huddl([group_id: group.id, creator_id: owner.id] ++ attrs))
      end

    archive = document(conn, "/groups/#{group.slug}?tab=past")
    links = Floki.attribute(archive, "a[href*='/huddlz/']", "href")
    assert links == ["/groups/#{group.slug}/huddlz/#{public.id}"]

    for huddl <- hidden do
      refute Floki.text(archive) =~ huddl.title
    end
  end

  test "archive page parameters normalize safely and cannot create endless pagination", %{
    conn: conn
  } do
    owner = generate(user())
    group = generate(group(actor: owner))
    generate(past_huddl(group_id: group.id, creator_id: owner.id, title: "Archived huddl"))
    path = "/groups/#{group.slug}?tab=past"

    for page <- ["0", "-1", "abc", "1"] do
      doc = document(conn, path <> "&page=" <> page)
      assert Floki.text(doc) =~ "Archived huddl"

      assert Floki.attribute(doc, "head link[rel=canonical]", "href") == [
               HuddlzWeb.Endpoint.url() <> path
             ]
    end

    response = get(conn, path <> "&page=999")
    assert redirected_to(response) == path
    assert Floki.text(document(conn, redirected_to(response))) =~ "Archived huddl"
    assert Floki.attribute(document(conn, path), "a[aria-label='Next page']", "href") == []
  end

  defp document(conn, path),
    do: conn |> get(path) |> html_response(200) |> Floki.parse_document!()
end
