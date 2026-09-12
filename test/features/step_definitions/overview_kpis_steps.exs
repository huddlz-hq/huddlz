defmodule OverviewKpisSteps do
  use Cucumber.StepDefinition

  import Ecto.Query, only: [from: 2]
  import ExUnit.Assertions
  import Huddlz.Generator
  import HuddlzWeb.ApiCase
  import Phoenix.ConnTest, only: [build_conn: 0, json_response: 2]
  import PhoenixTest

  require Ash.Query

  alias Huddlz.Accounts.User
  alias Huddlz.Communities.{Group, GroupMember, Huddl, HuddlAttendee}
  alias Huddlz.Repo

  step "the summary headings omit the selected range", %{session: session} = context do
    session
    |> assert_has("#kpi-members .label", text: "Members", exact: true)
    |> assert_has("#kpi-rsvps .label", text: "RSVPs", exact: true)
    |> assert_has("#kpi-showrate .label", text: "Show rate", exact: true)
    |> assert_has("#kpi-waitlist .label", text: "Waitlisted now", exact: true)

    context
  end

  step "{string} was started {int} months ago", %{args: [group_name, months]} = context do
    group = find_group(group_name)
    started_at = months_ago(months)

    Repo.update_all(from(m in "group_members", where: m.group_id == type(^group.id, :binary_id)),
      set: [created_at: started_at]
    )

    context
  end

  step "{int} members joined {string} {int} months ago",
       %{args: [count, group_name, months]} = context do
    seed_members(find_group(group_name), count, months_ago(months))
    context
  end

  step "{int} members joined {string} this month", %{args: [count, group_name]} = context do
    seed_members(find_group(group_name), count, DateTime.utc_now())
    context
  end

  step "the huddlz of {string} gathered {int} RSVPs {int} days ago",
       %{args: [group_name, count, days]} = context do
    seed_rsvps(find_group(group_name), count, days)
    context
  end

  step "the huddlz of {string} gathered {int} RSVP {int} days ago",
       %{args: [group_name, count, days]} = context do
    seed_rsvps(find_group(group_name), count, days)
    context
  end

  step "{int} people are waitlisted for {string}", %{args: [count, title]} = context do
    huddl = Huddl |> Ash.Query.filter(title == ^title) |> Ash.read_one!(authorize?: false)

    for _ <- 1..count//1 do
      attendee = generate(user(role: :user))

      Ash.Seed.seed!(HuddlAttendee, %{
        huddl_id: huddl.id,
        user_id: attendee.id,
        waitlisted_at: DateTime.utc_now()
      })
    end

    context
  end

  step "the {word} KPI shows {string} and {string}",
       %{args: [kpi, value, delta], session: session} = context do
    id = kpi_id(kpi)

    session
    |> assert_has("##{id} .value", text: value, exact: true)
    |> assert_has("##{id} .delta", text: delta)

    context
  end

  step "the overview URL records the period {string}",
       %{args: [period], session: session} = context do
    assert_path(session, "/organize/portland-elixir", query_params: %{"period" => period})
    context
  end

  step "the KPI sparklines are inline SVG with readable points", %{session: session} = context do
    for id <- ["kpi-members", "kpi-rsvps", "kpi-waitlist"] do
      assert_has(session, "##{id} svg.spark[data-points]")
    end

    # Owner plus the two who joined this month: the line ends at 3.
    assert_has(session, "#kpi-members svg.spark[data-points$=',3']")

    context
  end

  step "{string} reads the overview of {string} for {string} through GraphQL",
       %{args: [email, group_name, period]} = context do
    user = User |> Ash.Query.filter(email == ^email) |> Ash.read_one!(authorize?: false)
    group = find_group(group_name)

    response =
      build_conn()
      |> authenticated_conn(user)
      |> gql_post(~s|{ groupOverview(groupId: "#{group.id}", period: "#{period}") }|)
      |> json_response(200)

    Map.put(context, :overview_response, response)
  end

  step "the API overview shows {int} members and {int} joined this month",
       %{args: [count, joined]} = context do
    overview = overview_payload(context.overview_response)
    assert overview["members"]["count"] == count
    assert overview["members"]["joined_this_month"] == joined
    context
  end

  step "the API refuses the overview", context do
    response = context.overview_response
    assert is_nil(response["data"]["groupOverview"])
    assert [_ | _] = response["errors"]
    context
  end

  # The action returns a map; GraphQL carries it as JSON, sometimes as a
  # string, so accept both.
  defp overview_payload(%{"data" => %{"groupOverview" => payload}}) when is_binary(payload),
    do: Jason.decode!(payload)

  defp overview_payload(%{"data" => %{"groupOverview" => payload}}) when is_map(payload),
    do: payload

  defp overview_payload(response), do: flunk("unexpected overview response: #{inspect(response)}")

  defp kpi_id("Members"), do: "kpi-members"
  defp kpi_id("People"), do: "kpi-people"
  defp kpi_id("Groups"), do: "kpi-groups"
  defp kpi_id("RSVPs"), do: "kpi-rsvps"
  defp kpi_id("Waitlisted"), do: "kpi-waitlist"

  defp seed_members(group, count, joined_at) do
    for _ <- 1..count//1 do
      member = generate(user(role: :user))

      Ash.Seed.seed!(GroupMember, %{
        group_id: group.id,
        user_id: member.id,
        role: :member,
        created_at: joined_at
      })
    end
  end

  defp seed_rsvps(group, count, days_ago) do
    at = DateTime.add(DateTime.utc_now(), -days_ago, :day)

    huddl =
      generate(
        past_huddl(
          title: "Huddl from #{days_ago} days ago",
          group_id: group.id,
          creator_id: group.owner_id,
          is_private: false,
          starts_at: at,
          ends_at: DateTime.add(at, 2, :hour)
        )
      )

    for _ <- 1..count//1 do
      attendee = generate(user(role: :user))
      Ash.Seed.seed!(HuddlAttendee, %{huddl_id: huddl.id, user_id: attendee.id, rsvped_at: at})
    end
  end

  defp months_ago(months) do
    DateTime.utc_now()
    |> DateTime.to_date()
    |> Date.shift(month: -months)
    |> DateTime.new!(~T[12:00:00], "Etc/UTC")
  end

  defp find_group(name) do
    Group |> Ash.Query.filter(name == ^name) |> Ash.read_one!(authorize?: false)
  end
end
