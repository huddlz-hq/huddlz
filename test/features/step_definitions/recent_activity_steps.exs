defmodule RecentActivitySteps do
  use Cucumber.StepDefinition

  import Ecto.Query, only: [from: 2]
  import ExUnit.Assertions
  import Huddlz.Generator
  import HuddlzWeb.ApiCase
  import Phoenix.ConnTest, only: [build_conn: 0, json_response: 2]
  import PhoenixTest

  require Ash.Query

  alias Huddlz.Accounts.User
  alias Huddlz.Communities.{Group, GroupActivity, GroupMember, Huddl}
  alias Huddlz.Repo

  step "the huddl {string} was created in {string} last week with room for {int}",
       %{args: [title, group_name, capacity]} = context do
    group = find_group(group_name)
    host = Ash.get!(User, group.owner_id, authorize?: false)

    generate(
      huddl(
        title: title,
        group_id: group.id,
        creator_id: host.id,
        is_private: false,
        max_attendees: capacity,
        date: Date.add(eastern_today(), 10),
        actor: host
      )
    )

    # Everything logged so far happened when the huddl was set up.
    backdate_all(group, ago(7, "days"))
    context
  end

  step "{string} joined {string} yesterday", %{args: [name, group_name]} = context do
    join(name, group_name, ago(1, "days"))
    context
  end

  step "{string} joined {string} {int} {word} ago",
       %{args: [name, group_name, amount, unit]} = context do
    join(name, group_name, ago(amount, unit))
    context
  end

  step "{string} left {string} {int} {word} ago",
       %{args: [name, group_name, amount, unit]} = context do
    person = find_user(name)
    group = find_group(group_name)

    membership =
      GroupMember
      |> Ash.Query.filter(group_id == ^group.id and user_id == ^person.id)
      |> Ash.read_one!(authorize?: false)

    Ash.destroy!(membership, action: :leave_group, actor: person)
    backdate_latest(group, person, :left, ago(amount, unit))
    context
  end

  step "{string} RSVPd to {string} {int} {word} ago",
       %{args: [name, title, amount, unit]} = context do
    person = find_user(name)
    huddl = find_huddl(title)

    huddl |> Ash.Changeset.for_update(:rsvp, %{}, actor: person) |> Ash.update!()
    backdate_latest(huddl, person, :rsvped, ago(amount, unit))
    context
  end

  step "{string} cancelled their RSVP to {string} {int} {word} ago",
       %{args: [name, title, amount, unit]} = context do
    person = find_user(name)
    huddl = find_huddl(title)

    huddl |> Ash.Changeset.for_update(:cancel_rsvp, %{}, actor: person) |> Ash.update!()
    backdate_latest(huddl, person, :cancelled_rsvp, ago(amount, unit))
    context
  end

  step "{string} joined the waitlist for {string} {int} {word} ago",
       %{args: [name, title, amount, unit]} = context do
    person = find_user(name)
    huddl = find_huddl(title)

    huddl |> Ash.Changeset.for_update(:join_waitlist, %{}, actor: person) |> Ash.update!()
    backdate_latest(huddl, person, :waitlisted, ago(amount, unit))
    context
  end

  step "the feed lists, newest first:", %{session: session} = context do
    context.datatable.raw
    |> Enum.with_index(1)
    |> Enum.each(fn {[what, when_], position} ->
      session
      |> assert_has("#recent-activity .item:nth-child(#{position}) .what",
        text: what,
        exact: true
      )
      |> assert_has("#recent-activity .item:nth-child(#{position}) .when",
        text: when_,
        exact: true
      )
    end)

    context
  end

  step "the feed shows {string}", %{args: [line], session: session} = context do
    assert_has(session, "#recent-activity .item .what", text: line, exact: true)
    context
  end

  step "the recent activity panel links to the Members tab", %{session: session} = context do
    assert_has(session, "#recent-activity a[href='/organize/portland-elixir/members']",
      text: "All members"
    )

    context
  end

  step "{string} reads the activity of {string} through GraphQL",
       %{args: [email, group_name]} = context do
    user = User |> Ash.Query.filter(email == ^email) |> Ash.read_one!(authorize?: false)
    group = find_group(group_name)

    response =
      build_conn()
      |> authenticated_conn(user)
      |> gql_post(~s|{ groupActivity(groupId: "#{group.id}") { kind userId } }|)
      |> json_response(200)

    Map.put(context, :activity_response, response)
  end

  step "the API lists the activity", context do
    assert [%{"kind" => _} | _] = context.activity_response["data"]["groupActivity"]
    context
  end

  step "the API refuses the activity", context do
    response = context.activity_response
    assert is_nil(response["data"]["groupActivity"])
    assert [_ | _] = response["errors"]
    context
  end

  defp join(name, group_name, at) do
    person = find_user(name)
    group = find_group(group_name)

    GroupMember
    |> Ash.Changeset.for_create(:join_group, %{group_id: group.id}, actor: person)
    |> Ash.create!()

    backdate_latest(group, person, :joined, at)
  end

  defp ago(amount, "minutes"), do: DateTime.add(DateTime.utc_now(), -amount, :minute)
  defp ago(amount, "hours"), do: DateTime.add(DateTime.utc_now(), -amount, :hour)
  defp ago(amount, "days"), do: DateTime.add(DateTime.utc_now(), -amount, :day)

  # The log is written as the action runs; the scenario then says when it
  # happened.
  defp backdate_latest(%Group{id: group_id}, person, kind, at) do
    GroupActivity
    |> Ash.Query.filter(group_id == ^group_id and user_id == ^person.id and kind == ^kind)
    |> backdate(at)
  end

  defp backdate_latest(%Huddl{id: huddl_id}, person, kind, at) do
    GroupActivity
    |> Ash.Query.filter(huddl_id == ^huddl_id and user_id == ^person.id and kind == ^kind)
    |> backdate(at)
  end

  defp backdate(query, at) do
    row =
      query
      |> Ash.Query.sort(occurred_at: :desc)
      |> Ash.Query.limit(1)
      |> Ash.read_one!(authorize?: false)

    assert row, "expected the action to have been logged"

    Repo.update_all(from(a in "group_activities", where: a.id == type(^row.id, :binary_id)),
      set: [occurred_at: at]
    )
  end

  defp backdate_all(%Group{id: group_id}, at) do
    Repo.update_all(
      from(a in "group_activities", where: a.group_id == type(^group_id, :binary_id)),
      set: [occurred_at: at]
    )
  end

  defp find_user(display_name) do
    User |> Ash.Query.filter(display_name == ^display_name) |> Ash.read_one!(authorize?: false)
  end

  defp find_group(name) do
    Group |> Ash.Query.filter(name == ^name) |> Ash.read_one!(authorize?: false)
  end

  defp find_huddl(title) do
    Huddl |> Ash.Query.filter(title == ^title) |> Ash.read_one!(authorize?: false)
  end
end
