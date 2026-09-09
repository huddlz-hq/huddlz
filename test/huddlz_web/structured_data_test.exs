defmodule HuddlzWeb.StructuredDataTest do
  use HuddlzWeb.ConnCase, async: true
  import Phoenix.LiveViewTest, only: [live: 2]

  alias Huddlz.Communities.Workers.RegenerateRecurringSeries

  @moduletag :structured_data

  setup do
    owner = generate(user())
    group = generate(group(actor: owner))
    %{owner: owner, group: group}
  end

  test "attendance modes describe public locations without disclosing join links",
       %{conn: conn, owner: owner, group: group} do
    for {mode, attendance, locations} <- [
          {:in_person, "OfflineEventAttendanceMode", ["Place"]},
          {:virtual, "OnlineEventAttendanceMode", ["VirtualLocation"]},
          {:hybrid, "MixedEventAttendanceMode", ["Place", "VirtualLocation"]}
        ] do
      huddl =
        generate(
          huddl(
            actor: owner,
            group_id: group.id,
            event_type: mode,
            virtual_link: "https://example.test/private-join-secret",
            date: ~D[2030-01-20],
            start_time: ~T[12:00:00],
            duration_minutes: 90,
            thumbnail_url: "https://example.test/public-cover.jpg"
          )
        )

      path = ~p"/groups/#{group.slug}/huddlz/#{huddl.id}"

      for viewer <- [conn, login(conn, owner)] do
        document =
          %{viewer | host: "untrusted.example"}
          |> get(path <> "?utm_source=share")
          |> html_response(200)
          |> Floki.parse_document!()

        data = structured_data(document)
        assert data["@context"] == "https://schema.org"
        assert data["@type"] == "Event"
        assert data["eventAttendanceMode"] == "https://schema.org/#{attendance}"
        assert data["eventStatus"] == "https://schema.org/EventScheduled"
        assert data["startDate"] == "2030-01-20T12:00:00-05:00"
        assert data["endDate"] == "2030-01-20T13:30:00-05:00"
        assert Enum.map(List.wrap(data["location"]), & &1["@type"]) == locations
        assert data["url"] == HuddlzWeb.Endpoint.url() <> path
        assert data["@id"] == data["url"]
        assert [data["url"]] == Floki.attribute(document, "link[rel=canonical]", "href")
        assert [data["url"]] == Floki.attribute(document, "meta[property='og:url']", "content")
        assert data["organizer"]["url"] == url(~p"/groups/#{group.slug}")
        refute Map.has_key?(data, "image")
        refute Jason.encode!(data) =~ "private-join-secret"

        for location <- List.wrap(data["location"]) do
          case location["@type"] do
            "Place" ->
              assert location["address"] == %{
                       "@type" => "PostalAddress",
                       "name" => "123 Main St, Anytown, USA"
                     }

            "VirtualLocation" ->
              assert location == %{"@type" => "VirtualLocation", "name" => "Online"}
          end
        end
      end
    end
  end

  test "JSON strings round-trip without introducing HTML or executable script",
       %{conn: conn, owner: owner, group: group} do
    unsafe = "Quotes \" & café 雪 </script><script>alert(1)</script><!--<script>\u2028\u2029 end"

    huddl =
      generate(huddl(actor: owner, group_id: group.id, title: unsafe, description: unsafe))

    document =
      conn
      |> get(~p"/groups/#{group.slug}/huddlz/#{huddl.id}")
      |> html_response(200)
      |> Floki.parse_document!()

    data = structured_data(document)
    assert data["name"] == unsafe
    assert data["description"] == unsafe
    assert Floki.find(document, "h1") |> Floki.text() == unsafe
    assert Floki.find(document, "script:not([type='application/ld+json']):not([src])") == []
    assert Floki.find(document, "#huddl-cover-#{huddl.id}") == []

    group =
      group
      |> Ash.Changeset.for_update(:update_details, %{description: unsafe}, actor: owner)
      |> Ash.update!()

    group_document =
      conn |> get(~p"/groups/#{group.slug}") |> html_response(200) |> Floki.parse_document!()

    assert structured_data(group_document)["description"] == unsafe
  end

  test "artwork follows visible group fallback and huddl artwork with absolute URLs",
       %{conn: conn, owner: owner, group: group} do
    huddl = generate(huddl(actor: owner, group_id: group.id))
    group_path = "/uploads/group_images/#{group.id}/cover_thumb.jpg"
    huddl_path = "/uploads/huddl_images/#{huddl.id}/cover_thumb.jpg"

    Huddlz.Communities.GroupImage
    |> Ash.Changeset.for_create(:create, %{
      filename: "cover.jpg",
      content_type: "image/jpeg",
      size_bytes: 123,
      storage_path: group_path,
      thumbnail_path: group_path,
      group_id: group.id
    })
    |> Ash.create!(authorize?: false)

    for path <- [~p"/groups/#{group.slug}", ~p"/groups/#{group.slug}/huddlz/#{huddl.id}"] do
      document = conn |> get(path) |> html_response(200) |> Floki.parse_document!()
      assert structured_data(document)["image"] == HuddlzWeb.Endpoint.url() <> group_path

      assert [structured_data(document)["image"]] ==
               Floki.attribute(document, "meta[property='og:image']", "content")
    end

    Huddlz.Communities.HuddlCoverImage
    |> Ash.Changeset.for_create(:create, %{
      filename: "cover.jpg",
      content_type: "image/jpeg",
      size_bytes: 123,
      storage_path: huddl_path,
      thumbnail_path: huddl_path,
      huddl_id: huddl.id
    })
    |> Ash.create!(authorize?: false)

    document =
      conn
      |> get(~p"/groups/#{group.slug}/huddlz/#{huddl.id}")
      |> html_response(200)
      |> Floki.parse_document!()

    assert structured_data(document)["image"] == HuddlzWeb.Endpoint.url() <> huddl_path
  end

  test "restricted pages omit structured data even for organizers",
       %{conn: conn, owner: owner, group: group} do
    private_group = generate(group(actor: owner, is_public: false))
    cancelled = generate(huddl(actor: owner, group_id: group.id))
    Huddlz.Communities.cancel_huddl!(cancelled, "Private cancellation reason", actor: owner)

    paths =
      for {target_group, opts} <- [
            {group, [is_private: true]},
            {private_group, []},
            {group, [lifecycle_state: :draft]}
          ] do
        huddl = generate(huddl([actor: owner, group_id: target_group.id] ++ opts))
        ~p"/groups/#{target_group.slug}/huddlz/#{huddl.id}"
      end

    for path <- [
          ~p"/groups/#{private_group.slug}",
          ~p"/groups/#{group.slug}/huddlz/#{cancelled.id}" | paths
        ] do
      html = conn |> login(owner) |> get(path) |> html_response(200)
      assert Floki.find(Floki.parse_document!(html), "script[type='application/ld+json']") == []
      assert {404, _, body} = assert_error_sent(404, fn -> get(conn, path) end)
      assert Floki.find(Floki.parse_document!(body), "script[type='application/ld+json']") == []
      refute body =~ "Private cancellation reason"
    end
  end

  test "schedule edits replace current dates in HTTP and connected metadata without inventing history",
       %{conn: conn, owner: owner, group: group} do
    huddl =
      generate(
        huddl(
          actor: owner,
          group_id: group.id,
          date: ~D[2030-07-20],
          start_time: ~T[12:00:00],
          duration_minutes: 60
        )
      )

    path = ~p"/groups/#{group.slug}/huddlz/#{huddl.id}"
    {:ok, view, _html} = Phoenix.LiveViewTest.live(conn, path)

    Huddlz.Communities.update_huddl!(
      huddl,
      %{
        date: ~D[2030-11-20],
        start_time: ~T[15:00:00],
        duration_minutes: 90,
        title: "New schedule"
      },
      actor: owner
    )

    for html <- [Phoenix.LiveViewTest.render(view), conn |> get(path) |> html_response(200)] do
      data = html |> Floki.parse_document!() |> structured_data()
      assert data["name"] == "New schedule"
      assert data["startDate"] == "2030-11-20T15:00:00-05:00"
      assert data["endDate"] == "2030-11-20T16:30:00-05:00"
      assert data["eventStatus"] == "https://schema.org/EventScheduled"
      refute Map.has_key?(data, "previousStartDate")
      assert data["@id"] == HuddlzWeb.Endpoint.url() <> path
    end
  end

  test "live navigation replaces detail metadata and removes it when leaving detail pages",
       %{conn: conn, owner: owner, group: group} do
    huddl = generate(huddl(actor: owner, group_id: group.id))
    {:ok, view, _html} = Phoenix.LiveViewTest.live(conn, ~p"/groups/#{group.slug}")

    assert Phoenix.LiveViewTest.render(view)
           |> Floki.parse_document!()
           |> structured_data()
           |> Map.fetch!("@type") == "Organization"

    {:ok, huddl_view, html} =
      view
      |> Phoenix.LiveViewTest.element("#huddlz-#{huddl.id}")
      |> Phoenix.LiveViewTest.render_click()
      |> Phoenix.LiveViewTest.follow_redirect(conn)

    assert html |> Floki.parse_document!() |> structured_data() |> Map.fetch!("@id") ==
             url(~p"/groups/#{group.slug}/huddlz/#{huddl.id}")

    {:ok, _home_view, home_html} =
      huddl_view
      |> Phoenix.LiveViewTest.element("a[aria-label='huddlz home']")
      |> Phoenix.LiveViewTest.render_click()
      |> Phoenix.LiveViewTest.follow_redirect(conn)

    assert Floki.find(Floki.parse_document!(home_html), "script[type='application/ld+json']") ==
             []
  end

  test "recurring occurrences have separate identities and local dates across daylight saving",
       %{conn: conn, owner: owner, group: group} do
    huddl =
      generate(
        huddl(
          actor: owner,
          creator_id: owner.id,
          group_id: group.id,
          date: ~D[2030-03-03],
          start_time: ~T[12:00:00],
          duration_minutes: 60,
          is_recurring: true,
          frequency: "weekly",
          repeat_until: ~D[2030-03-18]
        )
      )

    assert :ok =
             RegenerateRecurringSeries.perform(%Oban.Job{
               args: %{"huddl_id" => huddl.id},
               attempt: 1,
               max_attempts: 3
             })

    paths =
      conn
      |> get(~p"/groups/#{group.slug}")
      |> html_response(200)
      |> Floki.parse_document!()
      |> Floki.attribute("#group-huddl-grid a[id^='huddlz-']", "href")

    assert length(paths) == 3

    data =
      Enum.map(paths, fn path ->
        document = conn |> get(path) |> html_response(200) |> Floki.parse_document!()
        data = structured_data(document)
        assert [data["@id"]] == Floki.attribute(document, "link[rel=canonical]", "href")
        data
      end)

    assert Enum.map(data, & &1["startDate"]) == [
             "2030-03-03T12:00:00-05:00",
             "2030-03-10T12:00:00-04:00",
             "2030-03-17T12:00:00-04:00"
           ]

    assert data |> Enum.map(& &1["@id"]) |> Enum.uniq() |> length() == 3
  end

  test "completed public huddlz retain their actual schedule", %{
    conn: conn,
    owner: owner,
    group: group
  } do
    huddl =
      generate(
        past_huddl(
          group_id: group.id,
          creator_id: owner.id,
          lifecycle_state: :completed,
          starts_at: ~U[2025-07-20 16:00:00Z],
          ends_at: ~U[2025-07-20 17:00:00Z]
        )
      )

    data =
      conn
      |> get(~p"/groups/#{group.slug}/huddlz/#{huddl.id}")
      |> html_response(200)
      |> Floki.parse_document!()
      |> structured_data()

    assert data["startDate"] == "2025-07-20T12:00:00-04:00"
    assert data["endDate"] == "2025-07-20T13:00:00-04:00"
    refute Map.has_key?(data, "previousStartDate")
  end

  defp structured_data(document) do
    assert [block] = Floki.find(document, "script[type='application/ld+json']")
    block |> Floki.text(js: true) |> Jason.decode!()
  end
end
