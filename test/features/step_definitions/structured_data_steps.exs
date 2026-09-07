defmodule StructuredDataSteps do
  use Cucumber.StepDefinition

  import ExUnit.Assertions
  import Huddlz.Generator
  import Phoenix.ConnTest

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

    {:ok, Map.merge(context, %{structured_group: group, structured_huddl: huddl})}
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
end
