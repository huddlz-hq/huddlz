defmodule ApiHostingGroupSteps do
  use Cucumber.StepDefinition

  import ExUnit.Assertions
  import Huddlz.Generator

  step "a public huddl hosted by {string}", %{args: [name]} = context do
    owner = generate(user())
    group = generate(group(name: name, actor: owner, is_public: true))
    huddl = generate(huddl(group_id: group.id, actor: owner, title: "Saturday Coffee"))

    Map.merge(context, %{hosting_group: group, hosted_huddl: huddl})
  end

  step "I request the huddl's hosting group through {string}", %{args: [api]} = context do
    response = request_host(context.conn, context.hosted_huddl.id, api)
    Map.merge(context, %{hosting_response: response, hosting_api: api})
  end

  step "I belong to the private group hosting {string}", %{args: [title]} = context do
    owner = generate(user())
    viewer = generate(user())

    {group, [membership]} =
      generate_group_with_members(
        owner: owner,
        group: [name: "Brooklyn Coffee Club", is_public: false],
        members: [%{user: viewer, role: :member}]
      )

    huddl = generate(huddl(group_id: group.id, actor: owner, title: title))

    Map.merge(context, %{
      hosting_group: group,
      hosted_huddl: huddl,
      hosting_owner: owner,
      hosting_viewer: viewer,
      hosting_membership: membership,
      conn: HuddlzWeb.ApiCase.authenticated_conn(context.conn, viewer)
    })
  end

  step "I have RSVP history for the cancelled huddl but have left its group", context do
    Huddlz.Communities.rsvp_huddl!(context.hosted_huddl, actor: context.hosting_viewer)

    cancelled =
      Huddlz.Communities.cancel_huddl!(context.hosted_huddl, nil, %{},
        actor: context.hosting_owner
      )

    context.hosting_membership
    |> Ash.Changeset.for_destroy(:leave_group, %{}, actor: context.hosting_viewer)
    |> Ash.destroy!()

    Map.put(context, :hosted_huddl, cancelled)
  end

  step "the API returns the huddl with unavailable hosting information", context do
    response = Phoenix.ConnTest.json_response(context.hosting_response, 200)
    refute Map.has_key?(response, "errors")
    assert_unavailable_host(response, context.hosting_api, context.hosted_huddl.id)
    refute context.hosting_response.resp_body =~ context.hosting_group.id
    refute context.hosting_response.resp_body =~ to_string(context.hosting_group.name)
    refute context.hosting_response.resp_body =~ context.hosting_group.slug
    context
  end

  step "I am requesting the host as {string}", %{args: [viewer]} = context do
    Map.put(context, :conn, outsider_conn(viewer))
  end

  step "the API does not reveal the huddl or its hosting group", context do
    assert_inaccessible_huddl(context.hosting_response, context.hosting_api)
    refute context.hosting_response.resp_body =~ context.hosted_huddl.title
    refute context.hosting_response.resp_body =~ context.hosting_group.id
    refute context.hosting_response.resp_body =~ to_string(context.hosting_group.name)
    context
  end

  step "the API identifies {string} as the hosting group", %{args: [name]} = context do
    response = Phoenix.ConnTest.json_response(context.hosting_response, 200)
    refute Map.has_key?(response, "errors")
    group = hosting_group(response, context.hosting_api)

    assert group == %{
             "id" => context.hosting_group.id,
             "name" => name,
             "slug" => context.hosting_group.slug
           }

    context
  end

  defp request_host(conn, id, "GraphQL") do
    HuddlzWeb.ApiCase.gql_post(
      conn,
      """
      query HuddlDetail($id: ID!) {
        getHuddl(id: $id) { id title group { id name slug } }
      }
      """,
      %{"id" => id}
    )
  end

  defp request_host(conn, id, "JSON:API") do
    Phoenix.ConnTest.dispatch(conn, HuddlzWeb.Endpoint, :get, "/api/json/huddlz/#{id}", %{
      "include" => "group",
      "fields" => %{"group" => "name,slug"}
    })
  end

  defp outsider_conn("anonymous"), do: Phoenix.ConnTest.build_conn()

  defp outsider_conn("nonmember") do
    HuddlzWeb.ApiCase.authenticated_conn(Phoenix.ConnTest.build_conn(), generate(user()))
  end

  defp assert_inaccessible_huddl(conn, "GraphQL") do
    response = Phoenix.ConnTest.json_response(conn, 200)
    assert %{"data" => %{"getHuddl" => nil}} = response
  end

  defp assert_inaccessible_huddl(conn, "JSON:API") do
    response = Phoenix.ConnTest.json_response(conn, 404)
    assert [%{"code" => "not_found"}] = response["errors"]
  end

  defp assert_unavailable_host(response, "GraphQL", id) do
    assert %{"id" => ^id, "title" => "Saturday Coffee", "group" => nil} =
             response["data"]["getHuddl"]
  end

  defp assert_unavailable_host(response, "JSON:API", id) do
    assert response["data"]["id"] == id
    assert response["data"]["attributes"]["title"] == "Saturday Coffee"
    assert %{"data" => nil} = response["data"]["relationships"]["group"]
    assert response["included"] == []
  end

  defp hosting_group(response, "GraphQL"), do: response["data"]["getHuddl"]["group"]

  defp hosting_group(response, "JSON:API") do
    linkage = response["data"]["relationships"]["group"]["data"]
    assert %{"type" => "group", "id" => id} = linkage
    assert [group] = response["included"]
    assert group["type"] == "group"
    assert group["id"] == id
    Map.put(group["attributes"], "id", id)
  end
end
