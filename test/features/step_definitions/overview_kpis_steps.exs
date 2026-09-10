defmodule OverviewKpisSteps do
  use Cucumber.StepDefinition

  import Ecto.Query, only: [from: 2]
  import Huddlz.Generator
  import PhoenixTest

  require Ash.Query

  alias Huddlz.Communities.{Group, GroupMember, Huddl, HuddlAttendee}
  alias Huddlz.Repo

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

  defp kpi_id("Members"), do: "kpi-members"
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
