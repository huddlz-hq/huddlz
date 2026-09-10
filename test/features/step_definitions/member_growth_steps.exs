defmodule MemberGrowthSteps do
  use Cucumber.StepDefinition

  import Ecto.Query, only: [from: 2]
  import Huddlz.Generator
  import PhoenixTest

  require Ash.Query

  alias Huddlz.Accounts.User
  alias Huddlz.Communities
  alias Huddlz.Communities.{Group, GroupActivity, GroupMember}
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

  step "{string} joined {string} {int} months ago and left {int} months ago",
       %{args: [name, group_name, joined_ago, left_ago]} = context do
    person = User |> Ash.Query.filter(display_name == ^name) |> Ash.read_one!(authorize?: false)
    group = find_group(group_name)

    Communities.join_group!(group.id, actor: person)
    backdate_activity(group, person, :joined, month_start(group, joined_ago))

    membership =
      GroupMember
      |> Ash.Query.filter(group_id == ^group.id and user_id == ^person.id)
      |> Ash.read_one!(authorize?: false)

    Communities.leave_group!(membership, actor: person)
    backdate_activity(group, person, :left, month_start(group, left_ago))
    context
  end

  step "{string} rejoined {string} {int} month ago",
       %{args: [name, group_name, months]} = context do
    person = User |> Ash.Query.filter(display_name == ^name) |> Ash.read_one!(authorize?: false)
    group = find_group(group_name)
    membership = Communities.join_group!(group.id, actor: person)
    at = month_start(group, months)

    Repo.update_all(from(m in "group_members", where: m.id == type(^membership.id, :binary_id)),
      set: [created_at: DateTime.shift_zone!(at, "Etc/UTC")]
    )

    backdate_activity(group, person, :joined, at)
    context
  end

  step "the month {int} months ago shows {int} joined and {int} left, and the line stands at {int} after it",
       %{args: [months, joined, left, members], session: session} = context do
    label = month_label(months)

    session
    |> assert_has("#member-growth .col[data-label='#{label}'][data-joined='#{joined}']")
    |> assert_has("#member-growth .col.left[data-label='#{label}'][data-left='#{left}']")
    |> assert_has("#member-growth .dot[data-label='#{label}'][data-members='#{members}']")

    context
  end

  step "{string} was added to {string} {int} months ago, accepted an invitation {int} months ago and left {int} months ago",
       %{args: [name, group_name, joined_ago, accepted_ago, left_ago]} = context do
    person = User |> Ash.Query.filter(display_name == ^name) |> Ash.read_one!(authorize?: false)
    group = find_group(group_name)
    owner = Ash.get!(User, group.owner_id, authorize?: false)
    invitation = Communities.invite_to_group!(group.id, person.id, :member, actor: owner)
    membership = Communities.add_member!(group.id, person.id, :member, actor: owner)
    backdate_activity(group, person, :joined, month_start(group, joined_ago))

    Communities.accept_group_invitation!(invitation, actor: person)
    backdate_activity(group, person, :accepted_invitation, month_start(group, accepted_ago))

    Communities.leave_group!(membership, actor: person)
    backdate_activity(group, person, :left, month_start(group, left_ago))
    context
  end

  step "the growth panel head shows {string} net in {string} from {string} and {string}",
       %{args: [net, period, joined, left], session: session} = context do
    session
    |> assert_has("#member-growth-panel .stat .big", text: net, exact: true)
    |> assert_has("#member-growth-panel .stat .cmp", text: "in #{period}")
    |> assert_has("#member-growth-panel .stat .cmp", text: joined)
    |> assert_has("#member-growth-panel .stat .cmp", text: left)

    context
  end

  step "the Members sparkline starts at {int}, dips from {int} to {int}, and ends at {int}",
       %{args: [first, before_leave, after_leave, last], session: session} = context do
    assert_has(
      session,
      "#spark-members[data-points^='#{first},'][data-points*=',#{before_leave},#{after_leave},'][data-points$=',#{last}']"
    )

    context
  end

  step "no month shows anyone leaving", %{session: session} = context do
    none = List.duplicate("0", 12) |> Enum.join(",")
    assert_has(session, "#member-growth-bars[data-left='#{none}']")
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

  # The log is written as the action runs; the scenario then says when.
  defp backdate_activity(group, person, kind, at) do
    row =
      GroupActivity
      |> Ash.Query.filter(group_id == ^group.id and user_id == ^person.id and kind == ^kind)
      |> Ash.Query.sort(occurred_at: :desc)
      |> Ash.Query.limit(1)
      |> Ash.read_one!(authorize?: false)

    Repo.update_all(from(a in "group_activities", where: a.id == type(^row.id, :binary_id)),
      set: [occurred_at: DateTime.shift_zone!(at, "Etc/UTC")]
    )
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
