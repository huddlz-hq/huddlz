defmodule OrganizerDropInLinesSteps do
  use Cucumber.StepDefinition

  import ExUnit.Assertions
  import HuddlzWeb.ApiCase, only: [authenticated_conn: 2, gql_post: 2]
  import Phoenix.ConnTest, only: [build_conn: 0, json_response: 2]
  import PhoenixTest

  require Ash.Query

  alias Huddlz.Accounts.User
  alias Huddlz.Communities.Group

  @growth "#member-growth-panel"
  @next "#next-huddl.panel"
  @feed "#recent-activity .item .what"

  step "member growth says {string}", %{args: [text]} = context do
    assert_has(context.session, "#{@growth} .stat", text: text)
    context
  end

  step "member growth does not mention RSVPing first", context do
    refute_has(context.session, @growth, text: "RSVPd to a huddl first")
    context
  end

  step "the next huddl says {string}", %{args: [text]} = context do
    assert_has(context.session, @next, text: text)
    context
  end

  step "the next huddl does not mention people who aren't members", context do
    refute_has(context.session, @next, text: "member yet")
    refute_has(context.session, @next, text: "members yet")
    context
  end

  step "the feed shows {string} with the note {string}", %{args: [line, note]} = context do
    assert_has(context.session, @feed, text: "#{line} #{note}", exact: true)
    context
  end

  step "the feed shows {string} with no note", %{args: [line]} = context do
    assert_has(context.session, @feed, text: line, exact: true)
    context
  end

  step "the API overview says {int} joiner RSVPd to a huddl first", %{args: [count]} = context do
    assert overview(context)["growth"]["rsvped_first"] == count
    context
  end

  step "the API overview says {int} RSVP to the next huddl is from someone who isn't a member",
       %{args: [count]} = context do
    assert overview(context)["next_huddl"]["not_members"] == count
    context
  end

  step "{string} reads the drop-in notes on the activity of {string} through GraphQL",
       %{args: [email, group_name]} = context do
    group = Group |> Ash.Query.filter(name == ^group_name) |> Ash.read_one!(authorize?: false)

    response =
      build_conn()
      |> authenticated_conn(find_user(email))
      |> gql_post(
        ~s|{ groupActivity(groupId: "#{group.id}") { kind userId notAMemberYet rsvpedFirst } }|
      )
      |> json_response(200)

    refute Map.has_key?(response, "errors"), inspect(response)
    Map.put(context, :activity, response["data"]["groupActivity"])
  end

  step "the API activity says the RSVP from {string} is from someone who isn't a member yet",
       %{args: [email]} = context do
    assert %{"notAMemberYet" => true} = entry(context, email, "rsvped")
    context
  end

  step "the API activity says the join of {string} followed an RSVP to {string}",
       %{args: [email, title]} = context do
    assert %{"rsvpedFirst" => ^title} = entry(context, email, "joined")
    context
  end

  defp entry(context, email, kind) do
    user_id = find_user(email).id

    Enum.find(context.activity, &(&1["userId"] == user_id and &1["kind"] == kind)) ||
      flunk("no #{kind} entry for #{email} in #{inspect(context.activity)}")
  end

  defp overview(%{overview_response: %{"data" => %{"groupOverview" => payload}}})
       when is_binary(payload),
       do: Jason.decode!(payload)

  defp overview(%{overview_response: %{"data" => %{"groupOverview" => payload}}}), do: payload

  defp find_user(email) do
    User |> Ash.Query.filter(email == ^email) |> Ash.read_one!(authorize?: false)
  end
end
