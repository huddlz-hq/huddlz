defmodule GroupArchivalSteps do
  use Cucumber.StepDefinition
  alias Huddlz.Test.Helpers.Authentication
  import ExUnit.Assertions
  import PhoenixTest
  import Phoenix.ConnTest, only: [assert_error_sent: 2, dispatch: 4]

  step "I open the archived huddl {string}", %{args: [title]} = context do
    path = huddl_path(context, title)
    session = visit(context[:session] || context[:conn], path)
    Map.merge(context, %{session: session, conn: session})
  end

  step "I try to open the archived huddl {string}", %{args: [title]} = context do
    session = context[:session] || context[:conn]
    path = huddl_path(context, title)

    {404, _, body} =
      assert_error_sent 404, fn ->
        dispatch(session.conn, HuddlzWeb.Endpoint, :get, path)
      end

    Map.put(context, :error_body, body)
  end

  step "an archive email for {string} should be sent to {string}",
       %{args: [name, email]} = context do
    Oban.drain_queue(queue: :notifications)
    subject = "#{name} has been archived"

    assert_receive {:email, %Swoosh.Email{subject: ^subject, to: [{_, ^email}], text_body: body}},
                   1000

    assert body =~ "history"
    refute body =~ "deleted"
    context
  end

  step "I can open the archived group from its notification", context do
    session = context[:session] || context[:conn]
    session = session |> click_link("Open") |> assert_has("#group-archived-banner")
    Map.merge(context, %{session: session, conn: session})
  end

  step "I try to promote {string} in {string} through the API",
       %{args: [email, name]} = context do
    group = Enum.find(context.groups, &(to_string(&1.name) == name))
    user = Enum.find(context.users, &(to_string(&1.email) == email))
    member = Huddlz.Communities.get_membership_in_group!(group.id, actor: user)

    conn =
      Phoenix.ConnTest.build_conn()
      |> HuddlzWeb.ApiCase.authenticated_conn(context.current_user)
      |> Plug.Conn.put_req_header("content-type", "application/vnd.api+json")

    response =
      HuddlzWeb.ApiCase.gql_post(
        conn,
        "mutation { changeMemberRole(id: \"#{member.id}\", input: {role: \"organizer\"}) { result { id } errors { message } } }",
        %{}
      )

    Map.put(context, :archive_api_response, response)
  end

  step "the archived group change is rejected", context do
    assert context.archive_api_response.status == 200
    body = Jason.decode!(context.archive_api_response.resp_body)

    assert body["data"]["changeMemberRole"]["result"] == nil,
           context.archive_api_response.resp_body

    assert context.archive_api_response.resp_body =~ "archived"
    context
  end

  step "I try to add a location to {string} through the API", %{args: [name]} = context do
    group = Enum.find(context.groups, &(to_string(&1.name) == name))

    conn =
      Phoenix.ConnTest.build_conn() |> HuddlzWeb.ApiCase.authenticated_conn(context.current_user)

    query =
      "mutation ($input: CreateGroupLocationInput!) { createGroupLocation(input: $input) { result { id } errors { message } } }"

    response =
      HuddlzWeb.ApiCase.gql_post(conn, query, %{
        input: %{
          groupId: group.id,
          name: "New place",
          address: "1 Main St",
          latitude: 30.0,
          longitude: -81.0,
          timeZone: "America/New_York"
        }
      })

    Map.put(context, :archive_api_response, response)
  end

  step "the archived location change is rejected", context do
    body = Jason.decode!(context.archive_api_response.resp_body)

    assert body["data"]["createGroupLocation"]["result"] == nil,
           context.archive_api_response.resp_body

    assert context.archive_api_response.resp_body =~ "archived"
    context
  end

  step "I transfer the archived group {string} to {string}",
       %{args: [name, successor]} = context do
    session = context[:session] || context[:conn]

    session =
      session
      |> select("New owner", option: successor)
      |> click_button("Transfer group ownership")
      |> fill_in("Type #{name} to confirm", with: name)
      |> click_button("Transfer ownership")

    Map.merge(context, %{session: session, conn: session})
  end

  step "the owner archives {string} in another session", %{args: [name]} = context do
    group = Enum.find(context.groups, &(to_string(&1.name) == name))

    Phoenix.ConnTest.build_conn()
    |> Authentication.login(context.current_user)
    |> visit("/groups/#{group.slug}/edit")
    |> click_button("Archive group")
    |> click_button("Yes, archive group")
    |> assert_has("#group-archived-banner")

    context
  end

  step "{string} has an unpublished huddl {string}", %{args: [name, title]} = context do
    group = Enum.find(context.groups, &(to_string(&1.name) == name))
    owner = Enum.find(context.users, &(&1.id == group.owner_id))

    huddl =
      Huddlz.Generator.generate(
        Huddlz.Generator.huddl(
          group_id: group.id,
          actor: owner,
          title: title,
          lifecycle_state: :draft
        )
      )

    Map.update(context, :huddls, [huddl], &[huddl | &1])
  end

  step "I try to publish {string} through the API", %{args: [title]} = context do
    huddl = Enum.find(context.huddls, &(to_string(&1.title) == title))

    conn =
      Phoenix.ConnTest.build_conn() |> HuddlzWeb.ApiCase.authenticated_conn(context.current_user)

    response =
      HuddlzWeb.ApiCase.gql_post(
        conn,
        "mutation { publishHuddl(id: \"#{huddl.id}\") { result { id } errors { message } } }",
        %{}
      )

    Map.put(context, :archive_api_response, response)
  end

  step "the archived huddl change is rejected", context do
    body = Jason.decode!(context.archive_api_response.resp_body)
    assert body["data"]["publishHuddl"]["result"] == nil, context.archive_api_response.resp_body
    assert context.archive_api_response.resp_body =~ "archived"
    context
  end

  step "I upload an archived {string} cover through the API", %{args: [target]} = context do
    {path, type, field, id} =
      case target do
        "group" -> {"group_images", "group_image", "group_id", hd(context.groups).id}
        "huddl" -> {"huddl_images", "huddl_image", "huddl_id", hd(context.huddls).id}
      end

    conn =
      Phoenix.ConnTest.build_conn() |> HuddlzWeb.ApiCase.authenticated_conn(context.current_user)

    response =
      HuddlzWeb.ApiCase.multipart_post(
        conn,
        "/api/json/#{path}/upload",
        %{field => id, "file" => "the_file"},
        type: type,
        file: %{
          part_name: "the_file",
          path: "test/fixtures/test_image.jpg",
          filename: "cover.jpg",
          content_type: "image/jpeg"
        }
      )

    Map.put(context, :archive_api_response, response)
  end

  step "the archived cover upload is rejected", context do
    assert context.archive_api_response.status in [400, 403, 422],
           context.archive_api_response.resp_body

    assert context.archive_api_response.resp_body =~ "archived"
    context
  end

  step "I should see {int} archive notification(s) for {string}",
       %{args: [count, name]} = context do
    assert_has(context[:session] || context[:conn], "#notification-items .row-title",
      text: "Archived: #{name}",
      count: count
    )

    context
  end

  step "I archive {string} through the API", %{args: [name]} = context do
    group = Enum.find(context.groups, &(to_string(&1.name) == name))

    conn =
      Phoenix.ConnTest.build_conn() |> HuddlzWeb.ApiCase.authenticated_conn(context.current_user)

    response =
      HuddlzWeb.ApiCase.gql_post(
        conn,
        "mutation { archiveGroup(id: \"#{group.id}\") { result { id } errors { message } } }",
        %{}
      )

    Map.put(context, :archive_api_response, response)
  end

  step "API archival is {string}", %{args: [outcome]} = context do
    body = Jason.decode!(context.archive_api_response.resp_body)
    assert %{"data" => %{"archiveGroup" => result}} = body

    case outcome do
      "allowed" ->
        assert result["result"]["id"] == hd(context.groups).id

      "denied" ->
        assert result["result"] == nil
        assert result["errors"] != []
    end

    context
  end

  step "I close and restore {string} through {string}", %{args: [name, api]} = context do
    group = Enum.find(context.groups, &(to_string(&1.name) == name))

    conn =
      Phoenix.ConnTest.build_conn() |> HuddlzWeb.ApiCase.authenticated_conn(context.current_user)

    case api do
      "GraphQL" ->
        for mutation <- ["archiveGroup", "restoreGroup"] do
          body =
            conn
            |> HuddlzWeb.ApiCase.gql_post(
              "mutation { #{mutation}(id: \"#{group.id}\") { result { id } errors { message } } }",
              %{}
            )
            |> Phoenix.ConnTest.json_response(200)

          assert body["data"][mutation]["errors"] == [], inspect(body)
          assert body["data"][mutation]["result"]["id"] == group.id
        end

      "JSON:API" ->
        conn = Plug.Conn.put_req_header(conn, "content-type", "application/vnd.api+json")

        archived =
          Phoenix.ConnTest.dispatch(
            conn,
            HuddlzWeb.Endpoint,
            :delete,
            "/api/json/groups/#{group.id}/archive",
            %{}
          )

        assert archived.status in [200, 204], archived.resp_body

        restored =
          Phoenix.ConnTest.dispatch(
            conn,
            HuddlzWeb.Endpoint,
            :patch,
            "/api/json/groups/#{group.id}/restore",
            %{"data" => %{"id" => group.id, "type" => "group", "attributes" => %{}}}
          )

        assert restored.status == 200, restored.resp_body
    end

    context
  end

  step "{string} has a saved location named {string}", %{args: [name, location_name]} = context do
    group = Enum.find(context.groups, &(to_string(&1.name) == name))
    owner = Enum.find(context.users, &(&1.id == group.owner_id))

    Huddlz.Generator.generate(
      Huddlz.Generator.group_location(group_id: group.id, actor: owner, name: location_name)
    )

    context
  end

  step "I request archived addresses through {string}", %{args: [api]} = context do
    group = hd(context.groups)

    conn =
      Phoenix.ConnTest.build_conn() |> HuddlzWeb.ApiCase.authenticated_conn(context.current_user)

    response =
      case api do
        "GraphQL" ->
          HuddlzWeb.ApiCase.gql_post(
            conn,
            "query { groupLocations(groupId: \"#{group.id}\") { id name address } }",
            %{}
          )

        "JSON:API" ->
          dispatch(
            conn,
            HuddlzWeb.Endpoint,
            :get,
            "/api/json/group_locations/by_group?group_id=#{group.id}"
          )
      end

    assert response.status == 200, response.resp_body
    refute Map.has_key?(Jason.decode!(response.resp_body), "errors"), response.resp_body
    Map.put(context, :archive_api_response, response)
  end

  step "the retained address is {string}", %{args: [visibility]} = context do
    case visibility do
      "visible" -> assert context.archive_api_response.resp_body =~ "Retained meeting place"
      "hidden" -> refute context.archive_api_response.resp_body =~ "Retained meeting place"
    end

    context
  end

  defp huddl_path(context, title) do
    huddl = Enum.find(context.huddls, &(to_string(&1.title) == title))
    group = Enum.find(context.groups, &(&1.id == huddl.group_id))
    "/groups/#{group.slug}/huddlz/#{huddl.id}"
  end
end
