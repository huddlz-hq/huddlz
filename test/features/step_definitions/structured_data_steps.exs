defmodule StructuredDataSteps do
  use Cucumber.StepDefinition

  import ExUnit.Assertions
  import Huddlz.Generator
  import Phoenix.ConnTest

  alias Huddlz.Test.Helpers.Authentication

  @endpoint HuddlzWeb.Endpoint

  step "a public in-person huddl with a known schedule and address", context do
    owner = generate(user())

    group =
      generate(
        group(
          actor: owner,
          name: "Structured data community",
          description: "A community for sharing lunch."
        )
      )

    huddl =
      generate(
        huddl(
          actor: owner,
          group_id: group.id,
          title: "Community lunch",
          description: "Bring your lunch and meet the community.",
          date: ~D[2030-07-20],
          start_time: ~T[12:00:00],
          duration_minutes: 60
        )
      )

    {:ok,
     Map.merge(context, %{
       structured_group: group,
       structured_huddl: huddl,
       structured_owner: owner
     })}
  end

  step "a crawler requests the huddl page without signing in", context do
    path = "/groups/#{context.structured_group.slug}/huddlz/#{context.structured_huddl.id}"
    html = build_conn() |> get(path) |> html_response(200)
    {:ok, Map.put(context, :structured_html, html)}
  end

  step "the initial HTML describes that huddl once as structured data", context do
    document = Floki.parse_document!(context.structured_html)
    assert [block] = Floki.find(document, "script[type='application/ld+json']")
    data = block |> Floki.text(js: true) |> Jason.decode!()
    assert data["@type"] == "Event"
    assert data["name"] == "Community lunch"
    assert data["description"] == "Bring your lunch and meet the community."
    assert data["startDate"] == "2030-07-20T12:00:00-04:00"
    assert data["endDate"] == "2030-07-20T13:00:00-04:00"
    assert data["eventAttendanceMode"] == "https://schema.org/OfflineEventAttendanceMode"
    assert data["location"]["address"]["name"] == "123 Main St, Anytown, USA"
    assert data["organizer"]["name"] == "Structured data community"
    assert [data["url"]] == Floki.attribute(document, "link[rel=canonical]", "href")
    :ok
  end

  step "a crawler requests the group page without signing in", context do
    html = build_conn() |> get("/groups/#{context.structured_group.slug}") |> html_response(200)
    {:ok, Map.put(context, :structured_html, html)}
  end

  step "the initial HTML describes the public group once as an organization", context do
    document = Floki.parse_document!(context.structured_html)
    assert [block] = Floki.find(document, "script[type='application/ld+json']")
    data = block |> Floki.text(js: true) |> Jason.decode!()
    assert data["@type"] == "Organization"
    assert data["name"] == "Structured data community"
    assert data["description"] == "A community for sharing lunch."
    assert data["location"] == %{"@type" => "Place", "name" => "Test Location"}
    assert [data["url"]] == Floki.attribute(document, "link[rel=canonical]", "href")
    refute Map.has_key?(data, "member")
    :ok
  end

  step "the organizer cancels that huddl with a private reason", context do
    Huddlz.Communities.cancel_huddl!(context.structured_huddl, "Private organizer reason",
      actor: context.structured_owner
    )

    :ok
  end

  step "the public page reports cancellation with the original schedule", context do
    document = Floki.parse_document!(context.structured_html)
    assert [block] = Floki.find(document, "script[type='application/ld+json']")
    data = block |> Floki.text(js: true) |> Jason.decode!()
    assert data["eventStatus"] == "https://schema.org/EventCancelled"
    assert data["startDate"] == "2030-07-20T12:00:00-04:00"
    assert data["endDate"] == "2030-07-20T13:00:00-04:00"
    assert [data["url"]] == Floki.attribute(document, "link[rel=canonical]", "href")
    assert Floki.text(document) =~ "Cancelled"
    refute context.structured_html =~ "Private organizer reason"
    :ok
  end

  step "the cancelled huddl is in the sitemap but absent from discovery", context do
    assert sitemap_body() =~ context.structured_huddl.id

    html = build_conn() |> get("/groups/#{context.structured_group.slug}") |> html_response(200)

    refute Floki.find(Floki.parse_document!(html), "a[href$='#{context.structured_huddl.id}']") !=
             []

    :ok
  end

  step "the organizer moves that huddl to July 21 then July 22", context do
    Enum.reduce([~D[2030-07-21], ~D[2030-07-22]], context.structured_huddl, fn date, huddl ->
      Huddlz.Communities.update_huddl!(
        huddl,
        %{date: date, start_time: ~T[12:00:00], duration_minutes: 60},
        actor: context.structured_owner
      )
    end)

    :ok
  end

  step "the public page shows July 22 with July 21 as the previous start", context do
    document = Floki.parse_document!(context.structured_html)
    assert [block] = Floki.find(document, "script[type='application/ld+json']")
    data = block |> Floki.text(js: true) |> Jason.decode!()
    assert data["eventStatus"] == "https://schema.org/EventRescheduled"
    assert data["startDate"] == "2030-07-22T12:00:00-04:00"
    assert data["endDate"] == "2030-07-22T13:00:00-04:00"
    assert data["previousStartDate"] == "2030-07-21T12:00:00-04:00"
    assert [data["url"]] == Floki.attribute(document, "link[rel=canonical]", "href")
    assert Floki.text(Floki.find(document, "#schedule-update")) =~ "Rescheduled"

    assert Floki.attribute(document, "#schedule-update time", "datetime") == [
             "2030-07-21T12:00:00-04:00"
           ]

    :ok
  end

  step "that huddl has {word} privacy and is {word}", %{args: [privacy, change]} = context do
    huddl =
      Huddlz.Communities.update_huddl!(
        context.structured_huddl,
        %{
          is_private: privacy == "huddl",
          date: ~D[2030-07-22],
          start_time: ~T[12:00:00],
          duration_minutes: 60
        },
        actor: context.structured_owner
      )

    if change == "cancelled",
      do:
        Huddlz.Communities.cancel_huddl!(huddl, "Private organizer reason",
          actor: context.structured_owner
        )

    if privacy == "group" do
      context.structured_group
      |> Ash.Changeset.for_update(:update_details, %{is_public: false},
        actor: context.structured_owner
      )
      |> Ash.update!()
    end

    :ok
  end

  step "a crawler cannot read the huddl or find it in the sitemap", context do
    assert_error_sent 404, fn -> build_conn() |> get(huddl_path(context)) end
    refute sitemap_body() =~ context.structured_huddl.id
    :ok
  end

  step "cancellation metadata preserves the July 22 schedule", context do
    data = huddl_data(context.structured_html)
    assert data["eventStatus"] == "https://schema.org/EventCancelled"
    assert data["startDate"] == "2030-07-22T12:00:00-04:00"
    assert data["endDate"] == "2030-07-22T13:00:00-04:00"
    refute Map.has_key?(data, "previousStartDate")
    refute context.structured_html =~ "Private organizer reason"
    :ok
  end

  step "the organizer makes a {word} schedule edit", %{args: [edit]} = context do
    if edit == "draft" do
      draft =
        generate(
          huddl(
            actor: context.structured_owner,
            group_id: context.structured_group.id,
            lifecycle_state: :draft
          )
        )

      changed =
        Huddlz.Communities.update_huddl!(
          draft,
          %{date: ~D[2030-07-22], start_time: ~T[12:00:00], duration_minutes: 60},
          actor: context.structured_owner
        )

      published = Huddlz.Communities.publish_huddl!(changed, actor: context.structured_owner)
      {:ok, Map.put(context, :structured_huddl, published)}
    else
      Huddlz.Communities.update_huddl!(
        context.structured_huddl,
        %{ends_at: ~U[2030-07-20 18:00:00Z]},
        actor: context.structured_owner
      )

      :ok
    end
  end

  step "the public page shows a scheduled huddl without previous dates", context do
    data = huddl_data(context.structured_html)
    assert data["eventStatus"] == "https://schema.org/EventScheduled"
    refute Map.has_key?(data, "previousStartDate")
    assert Floki.find(Floki.parse_document!(context.structured_html), "#schedule-update") == []
    :ok
  end

  step "only an authorized viewer sees the cancellation reason", context do
    for viewer <- [context.structured_owner, generate(user())] do
      html =
        build_conn()
        |> Authentication.login(viewer)
        |> get(huddl_path(context))
        |> html_response(200)

      assert html =~ "Private organizer reason" == (viewer.id == context.structured_owner.id)
      refute Jason.encode!(huddl_data(html)) =~ "Private organizer reason"
    end

    :ok
  end

  step "the cancelled huddl's scheduled end has passed", context do
    huddl =
      generate(
        past_huddl(
          group_id: context.structured_group.id,
          creator_id: context.structured_owner.id,
          lifecycle_state: :cancelled,
          is_private: false
        )
      )

    {:ok, Map.put(context, :structured_huddl, huddl)}
  end

  step "the cancelled page retains its canonical URL but leaves the sitemap", context do
    data = huddl_data(context.structured_html)
    assert data["eventStatus"] == "https://schema.org/EventCancelled"

    assert [data["url"]] ==
             Floki.attribute(
               Floki.parse_document!(context.structured_html),
               "link[rel=canonical]",
               "href"
             )

    refute sitemap_body() =~ context.structured_huddl.id
    :ok
  end

  defp huddl_path(context),
    do: "/groups/#{context.structured_group.slug}/huddlz/#{context.structured_huddl.id}"

  defp huddl_data(html) do
    [block] = Floki.find(Floki.parse_document!(html), "script[type='application/ld+json']")
    block |> Floki.text(js: true) |> Jason.decode!()
  end

  defp sitemap_body do
    assert {:ok, :ok} = Huddlz.Sitemaps.refresh()
    conn = build_conn() |> get("/sitemap.xml")

    if conn.status == 204 do
      ""
    else
      Regex.scan(~r{<loc>(.*?)</loc>}, response(conn, 200), capture: :all_but_first)
      |> Enum.map_join(fn [url] -> build_conn() |> get(URI.parse(url).path) |> response(200) end)
    end
  end
end
