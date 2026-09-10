defmodule MemberGrowthSteps do
  use Cucumber.StepDefinition

  import Ecto.Query, only: [from: 2]
  import Huddlz.Generator
  import PhoenixTest

  require Ash.Query

  alias Huddlz.Communities.{Group, GroupMember}
  alias Huddlz.Repo

  step "{int} members joined {string} in each of the last {int} months",
       %{args: [count, group_name, months]} = context do
    group = find_group(group_name)

    # This month counts as one of them; each batch joins as its month opens.
    for n <- (months - 1)..0//-1 do
      joined_at = month_start(group, n)

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

    context
  end

  step "nobody joined {string} {int} months ago", %{args: [group_name, months]} = context do
    group = find_group(group_name)
    from = month_start(group, months)
    to = month_start(group, months - 1)

    Repo.delete_all(
      from(m in "group_members",
        where:
          m.group_id == type(^group.id, :binary_id) and m.created_at >= ^from and
            m.created_at < ^to
      )
    )

    context
  end

  step "the growth chart shows a point per month ending this month at {int} members with {int} joined",
       %{args: [members, joined], session: session} = context do
    this_month = month_label(0)

    session
    |> assert_has("#member-growth[data-unit='month'][data-buckets='12']")
    |> assert_has("#member-growth-line[data-points$=',#{members}']")
    |> assert_has("#member-growth-bars[data-points$=',#{joined}']")
    |> assert_has("#member-growth .dot[data-label='#{this_month}'][data-members='#{members}']")
    |> assert_has("#member-growth .col[data-label='#{this_month}'][data-joined='#{joined}']")

    context
  end

  step "the growth panel head shows {string} gained in {string}",
       %{args: [gained, period], session: session} = context do
    session
    |> assert_has("#member-growth-panel .stat .big", text: gained, exact: true)
    |> assert_has("#member-growth-panel .stat .cmp", text: "in #{period}", exact: true)

    context
  end

  step "the growth chart shows one bucket per week", %{session: session} = context do
    assert_has(session, "#member-growth[data-unit='week'][data-buckets='5']")
    context
  end

  step "the growth chart shows one bucket per fortnight", %{session: session} = context do
    assert_has(session, "#member-growth[data-unit='fortnight'][data-buckets='7']")
    context
  end

  step "the month {int} months ago shows a zero bar and the line stays flat at {int} through it",
       %{args: [months, members], session: session} = context do
    session
    |> assert_has("#member-growth .col[data-label='#{month_label(months)}'][data-joined='0']")
    |> assert_has(
      "#member-growth .dot[data-label='#{month_label(months + 1)}'][data-members='#{members}']"
    )
    |> assert_has(
      "#member-growth .dot[data-label='#{month_label(months)}'][data-members='#{members}']"
    )

    context
  end

  defp month_start(group, months_ago) do
    group.time_zone
    |> DateTime.now!()
    |> DateTime.to_date()
    |> Date.beginning_of_month()
    |> Date.shift(month: -months_ago)
    |> DateTime.new!(~T[00:00:00], group.time_zone)
  end

  defp month_label(months_ago) do
    eastern_today()
    |> Date.beginning_of_month()
    |> Date.shift(month: -months_ago)
    |> Calendar.strftime("%b")
  end

  defp find_group(name) do
    Group |> Ash.Query.filter(name == ^name) |> Ash.read_one!(authorize?: false)
  end
end
