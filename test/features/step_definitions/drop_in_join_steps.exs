defmodule DropInJoinSteps do
  use Cucumber.StepDefinition

  import ExUnit.Assertions
  import HuddlzWeb.ApiCase, only: [authenticated_conn: 2, gql_post: 3]
  import Phoenix.ConnTest, only: [build_conn: 0, dispatch: 5, json_response: 2]
  import PhoenixTest

  require Ash.Query

  alias Huddlz.Accounts.User
  alias Huddlz.Communities
  alias Huddlz.Communities.{Group, GroupMember, Huddl}

  step "I can join {string} from the huddl page", %{args: [_group_name]} = context do
    assert_has(context.session, "#huddl-group button", text: "Join group")
    context
  end

  step "I join {string} from the huddl page", %{args: [_group_name]} = context do
    session = within(context.session, "#huddl-group", &click_button(&1, "Join group"))
    Map.put(context, :session, session)
  end

  step "I am shown as a member of {string} on the huddl page", %{args: [_group_name]} = context do
    assert_has(context.session, "#huddl-group", text: "Member")
    refute_has(context.session, "#huddl-group button", text: "Join group")
    context
  end

  step "{string} has RSVPd to {string}", %{args: [email, title]} = context do
    user = User |> Ash.Query.filter(email == ^email) |> Ash.read_one!(authorize?: false)
    huddl = Huddl |> Ash.Query.filter(title == ^title) |> Ash.read_one!(authorize?: false)
    Communities.rsvp_huddl!(huddl, actor: user)
    context
  end

  step "the huddl page suggests joining {string}", %{args: [group_name]} = context do
    assert_has(context.session, "#huddl-join-suggestion",
      text: "Join #{group_name} to hear about their next huddlz."
    )

    context
  end

  step "the huddl page does not suggest joining {string}", %{args: [_group_name]} = context do
    refute_has(context.session, "#huddl-join-suggestion")
    context
  end

  step "I join {string} from the suggestion", %{args: [_group_name]} = context do
    session =
      within(context.session, "#huddl-join-suggestion", &click_button(&1, "Join group"))

    Map.put(context, :session, session)
  end

  step "I decline the suggestion to join {string}", %{args: [_group_name]} = context do
    session = within(context.session, "#huddl-join-suggestion", &click_button(&1, "Not now"))
    Map.put(context, :session, session)
  end

  step "{string} joined and then left {string}", %{args: [email, group_name]} = context do
    user = find_user(email)
    membership = Communities.join_group!(find_group(group_name).id, actor: user)
    :ok = Communities.leave_group!(membership, actor: user)
    context
  end

  step "{string} joined {string} and was removed by {string}",
       %{args: [email, group_name, organizer_email]} = context do
    user = find_user(email)
    group = find_group(group_name)
    membership = Communities.join_group!(group.id, actor: user)

    :ok =
      Communities.remove_member!(membership, group.id, user.id, actor: find_user(organizer_email))

    context
  end

  step "{string} lists the groups they've dropped in on through {string}",
       %{args: [email, api]} = context do
    conn = authenticated_conn(build_conn(), find_user(email))

    names =
      case api do
        "GraphQL" ->
          body =
            conn
            |> gql_post(
              ~s|query { viewerGroups(relationship: "dropped_in") { results { name } } }|,
              %{}
            )
            |> json_response(200)

          refute Map.has_key?(body, "errors"), inspect(body)
          Enum.map(body["data"]["viewerGroups"]["results"], & &1["name"])

        "JSON:API" ->
          conn
          |> dispatch(
            HuddlzWeb.Endpoint,
            :get,
            "/api/json/groups/mine?relationship=dropped_in",
            nil
          )
          |> json_response(200)
          |> Map.fetch!("data")
          |> Enum.map(& &1["attributes"]["name"])
      end

    Map.put(context, :api_groups, names)
  end

  step "{string} declines the suggestion to join {string} through {string}",
       %{args: [email, group_name, api]} = context do
    conn = authenticated_conn(build_conn(), find_user(email))
    group = find_group(group_name)

    case api do
      "GraphQL" ->
        body =
          conn
          |> gql_post(
            """
            mutation($input: DismissJoinSuggestionInput!) {
              dismissJoinSuggestion(input: $input) { result { dismissedAt } errors { message } }
            }
            """,
            %{"input" => %{"groupId" => group.id}}
          )
          |> json_response(200)

        refute Map.has_key?(body, "errors"), inspect(body)
        assert body["data"]["dismissJoinSuggestion"]["errors"] == []
        assert body["data"]["dismissJoinSuggestion"]["result"]["dismissedAt"]

      "JSON:API" ->
        conn
        |> Plug.Conn.put_req_header("content-type", "application/vnd.api+json")
        |> dispatch(
          HuddlzWeb.Endpoint,
          :post,
          "/api/json/drop_in_reminders/dismiss",
          Jason.encode!(%{
            data: %{type: "drop_in_reminder", attributes: %{group_id: group.id}}
          })
        )
        |> json_response(201)
    end

    context
  end

  step "the API returns the group {string}", %{args: [group_name]} = context do
    assert context.api_groups == [group_name]
    context
  end

  step "the API returns no groups", context do
    assert context.api_groups == []
    context
  end

  step "{string} does not belong to {string}", %{args: [email, group_name]} = context do
    refute membership(email, group_name)
    context
  end

  step "{string} belongs to {string}", %{args: [email, group_name]} = context do
    assert membership(email, group_name)
    context
  end

  defp find_user(email) do
    User |> Ash.Query.filter(email == ^email) |> Ash.read_one!(authorize?: false)
  end

  defp find_group(name) do
    Group |> Ash.Query.filter(name == ^name) |> Ash.read_one!(authorize?: false)
  end

  defp membership(email, group_name) do
    user = find_user(email)
    group = find_group(group_name)

    GroupMember
    |> Ash.Query.filter(group_id == ^group.id and user_id == ^user.id)
    |> Ash.read_one!(authorize?: false)
  end
end
