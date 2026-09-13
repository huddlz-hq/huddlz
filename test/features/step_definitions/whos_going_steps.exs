defmodule WhosGoingSteps do
  use Cucumber.StepDefinition

  import ExUnit.Assertions
  import Huddlz.Generator
  import HuddlzWeb.ApiCase, only: [authenticated_conn: 2, gql_post: 3]
  import Phoenix.ConnTest, only: [build_conn: 0, dispatch: 4, json_response: 2]
  import PhoenixTest

  require Ash.Query

  alias Huddlz.Accounts.User
  alias Huddlz.Communities
  alias Huddlz.Communities.{Group, Huddl, HuddlAttendee}

  step "an upcoming huddl {string} exists in {string}", %{args: [title, group_name]} = context do
    group = find_group(group_name)

    huddl =
      generate(
        huddl(
          title: title,
          group_id: group.id,
          creator_id: group.owner_id,
          is_private: false,
          event_type: :virtual,
          virtual_link: "https://meet.example.com/#{System.unique_integer([:positive])}"
        )
      )

    Map.update(context, :huddls, [huddl], &[huddl | &1])
  end

  step "a past huddl {string} exists in {string}", %{args: [title, group_name]} = context do
    group = find_group(group_name)

    huddl =
      generate(
        past_huddl(
          title: title,
          group_id: group.id,
          creator_id: group.owner_id,
          is_private: false,
          event_type: :virtual,
          virtual_link: "https://meet.example.com/#{System.unique_integer([:positive])}"
        )
      )

    Map.update(context, :huddls, [huddl], &[huddl | &1])
  end

  step "{string} and {string} have RSVPd to {string}",
       %{args: [first, second, title]} = context do
    huddl = find_huddl(title)
    Enum.each([first, second], &rsvp(find_user(&1), huddl))
    context
  end

  step "{int} more people have RSVPd to {string}", %{args: [count, title]} = context do
    huddl = find_huddl(title)
    for _ <- 1..count//1, do: rsvp(generate(user(role: :user)), huddl)
    context
  end

  step "{string} has room for {int} people", %{args: [title, room]} = context do
    huddl = find_huddl(title)

    Huddlz.Repo.query!("UPDATE huddlz SET max_attendees = $1 WHERE id = $2", [
      room,
      Ecto.UUID.dump!(huddl.id)
    ])

    context
  end

  step "{string} RSVPs to {string} in another session", %{args: [email, title]} = context do
    Communities.rsvp_huddl!(find_huddl(title), actor: find_user(email))
    context
  end

  step "the people going are {string}", %{args: [names]} = context do
    expected = names |> String.split(",") |> Enum.map(&String.trim/1)

    session =
      Enum.reduce(expected, context.session, fn name, session ->
        assert_has(session, "#huddl-going li", text: name)
      end)

    assert_has(session, "#huddl-going li", count: length(expected))
    context
  end

  step "{int} people going are named", %{args: [count]} = context do
    assert_has(context.session, "#huddl-going li", count: count)
    context
  end

  step "nobody going is named", context do
    refute_has(context.session, "#huddl-going li")
    context
  end

  step "{string} reads who is going to {string} through {string}",
       %{args: [email, title, api]} = context do
    huddl = find_huddl(title)
    conn = authenticated_conn(build_conn(), find_user(email))

    names =
      case api do
        "GraphQL" ->
          body =
            conn
            |> gql_post("query { huddlAttendees(huddlId: \"#{huddl.id}\") { displayName } }", %{})
            |> json_response(200)

          refute Map.has_key?(body, "errors"), inspect(body)
          Enum.map(body["data"]["huddlAttendees"], & &1["displayName"])

        "JSON:API" ->
          conn
          |> dispatch(
            HuddlzWeb.Endpoint,
            :get,
            "/api/json/huddl_attendees/by_huddl?huddl_id=#{huddl.id}"
          )
          |> json_response(200)
          |> Map.fetch!("data")
          |> Enum.map(& &1["attributes"]["display_name"])
      end

    Map.put(context, :people_going, names)
  end

  step "the API names {string} among the people going", %{args: [name]} = context do
    assert name in context.people_going
    context
  end

  step "the API names nobody", context do
    assert context.people_going == []
    context
  end

  defp rsvp(user, huddl) do
    HuddlAttendee
    |> Ash.Changeset.for_create(:rsvp, %{huddl_id: huddl.id, user_id: user.id})
    |> Ash.create!(authorize?: false)
  end

  defp find_group(name) do
    Group |> Ash.Query.filter(name == ^name) |> Ash.read_one!(authorize?: false)
  end

  defp find_user(email) do
    User |> Ash.Query.filter(email == ^email) |> Ash.read_one!(authorize?: false)
  end

  defp find_huddl(title) do
    Huddl
    |> Ash.Query.filter(title == ^title)
    |> Ash.Query.load(:group)
    |> Ash.read_one!(authorize?: false)
  end
end
