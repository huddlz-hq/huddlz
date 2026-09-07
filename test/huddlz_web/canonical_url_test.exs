defmodule HuddlzWeb.CanonicalURLTest do
  use HuddlzWeb.ConnCase, async: true

  test "anonymous public detail HTML has one configured absolute canonical matching Open Graph",
       %{conn: conn} do
    owner = generate(user())
    group = generate(group(actor: owner))

    huddl =
      generate(
        huddl(
          group_id: group.id,
          actor: owner,
          event_type: :virtual,
          virtual_link: "https://example.test/join"
        )
      )

    for path <- [~p"/groups/#{group.slug}", ~p"/groups/#{group.slug}/huddlz/#{huddl.id}"] do
      html =
        %{conn | host: "untrusted.example", scheme: :http}
        |> get(path <> "?utm_source=newsletter&ref=share")
        |> html_response(200)

      document = Floki.parse_document!(html)
      expected = HuddlzWeb.Endpoint.url() <> path
      assert Floki.attribute(document, "head link[rel=canonical]", "href") == [expected]
      assert Floki.attribute(document, "head meta[property='og:url']", "content") == [expected]
    end
  end

  test "discovery retains meaningful filters and pagination in initial HTML", %{conn: conn} do
    owner = generate(user())
    group = generate(group(actor: owner))

    for _ <- 1..21 do
      generate(
        huddl(
          group_id: group.id,
          actor: owner,
          title: "Canonical search",
          event_type: :virtual,
          virtual_link: "https://example.test/join"
        )
      )
    end

    for path <- [
          "/discover",
          "/discover?q=Canonical&page=2",
          "/discover?scope=groups&q=Canonical",
          "/discover?date_filter=this_week&event_type=virtual&sort=newest&location=cleared&future_filter=keep"
        ] do
      document = conn |> get(path) |> html_response(200) |> Floki.parse_document!()
      [canonical] = Floki.attribute(document, "head link[rel=canonical]", "href")
      assert URI.parse(canonical).path == "/discover"

      assert URI.decode_query(URI.parse(canonical).query || "") ==
               URI.decode_query(URI.parse(path).query || "")

      assert Floki.attribute(document, "head meta[property='og:url']", "content") == [canonical]
    end
  end

  test "private and lifecycle-restricted pages stay hidden from anonymous requests", %{conn: conn} do
    owner = generate(user())
    public_group = generate(group(actor: owner))
    private_group = generate(group(actor: owner, is_public: false))

    paths =
      for {group, opts} <- [
            {public_group, [is_private: true]},
            {private_group, []},
            {public_group, [lifecycle_state: :draft]}
          ] do
        huddl =
          generate(
            huddl(
              [
                group_id: group.id,
                actor: owner,
                event_type: :virtual,
                virtual_link: "https://example.test/join"
              ] ++ opts
            )
          )

        path = ~p"/groups/#{group.slug}/huddlz/#{huddl.id}"
        authorized_html = conn |> login(owner) |> get(path) |> html_response(200)

        assert Floki.attribute(
                 Floki.parse_document!(authorized_html),
                 "head link[rel=canonical]",
                 "href"
               ) == []

        path
      end

    private_path = ~p"/groups/#{private_group.slug}"
    authorized_html = conn |> login(owner) |> get(private_path) |> html_response(200)

    assert Floki.attribute(
             Floki.parse_document!(authorized_html),
             "head link[rel=canonical]",
             "href"
           ) == []

    for path <- [private_path | paths] do
      assert {404, _, body} = assert_error_sent(404, fn -> get(conn, path) end)

      assert Floki.attribute(Floki.parse_document!(body), "head link[rel=canonical]", "href") ==
               []

      refute body =~ "https://example.test/join"
    end
  end

  test "an incorrect group slug does not expose an alternate huddl page", %{conn: conn} do
    owner = generate(user())
    group = generate(group(actor: owner))

    huddl =
      generate(
        huddl(
          group_id: group.id,
          actor: owner,
          event_type: :virtual,
          virtual_link: "https://example.test/join"
        )
      )

    assert {404, _, _} =
             assert_error_sent(404, fn ->
               get(conn, "/groups/incorrect-slug/huddlz/#{huddl.id}")
             end)
  end
end
