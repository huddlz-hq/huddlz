defmodule OverviewTurnoutSteps do
  use Cucumber.StepDefinition

  import Ecto.Query, only: [from: 2]
  import Huddlz.Generator
  import PhoenixTest

  require Ash.Query

  alias Huddlz.Accounts.User
  alias Huddlz.Communities
  alias Huddlz.Communities.{Group, Huddl, HuddlAttendee}
  alias Huddlz.Repo

  step "{int} counted in-person huddlz in {string} each with {int} RSVPs and {int} in the room",
       %{args: [count, group_name, rsvps, in_room]} = context do
    group = find_group(group_name)
    owner = Ash.get!(User, group.owner_id, authorize?: false)

    # One a week, the most recent a week ago.
    for n <- 1..count//1 do
      starts_at = DateTime.add(DateTime.utc_now(), -(n * 7), :day)

      huddl =
        generate(
          past_huddl(
            title: "Counted huddl #{n}",
            group_id: group.id,
            creator_id: owner.id,
            is_private: false,
            event_type: :in_person,
            starts_at: starts_at,
            ends_at: DateTime.add(starts_at, 2, :hour)
          )
        )

      for _ <- 1..rsvps//1 do
        attendee = generate(user(role: :user))

        Ash.Seed.seed!(HuddlAttendee, %{
          huddl_id: huddl.id,
          user_id: attendee.id,
          rsvped_at: starts_at
        })
      end

      Communities.record_turnout!(huddl, %{in_room: in_room}, actor: owner)
    end

    context
  end

  step "{string} had room for {int}", %{args: [title, capacity]} = context do
    huddl = find_huddl(title)

    Repo.update_all(from(h in "huddlz", where: h.id == type(^huddl.id, :binary_id)),
      set: [max_attendees: capacity]
    )

    context
  end

  step "the Show rate KPI shows {string} and {string}",
       %{args: [value, delta], session: session} = context do
    session
    |> assert_has("#kpi-showrate .value", text: value, exact: true)
    |> assert_has("#kpi-showrate .delta", text: delta)

    context
  end

  step "the show rate sparkline has {int} points", %{args: [count], session: session} = context do
    assert_has(session, "#kpi-showrate svg.spark[data-count='#{count}']")
    context
  end

  step "the Show rate KPI reads as not yet available and points at recording turnout",
       %{session: session} = context do
    session
    |> assert_has("#kpi-showrate .value", text: "—", exact: true)
    |> assert_has("#kpi-showrate .delta a[href='/organize/portland-elixir/huddlz?filter=past']",
      text: "Record turnout"
    )

    context
  end

  step "the Show rate KPI draws an empty baseline where its sparkline would be",
       %{session: session} = context do
    session
    |> assert_has("#spark-showrate[data-count='0'][data-empty] line")
    |> assert_has("#kpi-showrate .value.muted")

    context
  end

  step "the turnout chart pairs {string} as {int} RSVPs and {int} came, with a capacity tick at {int}",
       %{args: [title, rsvps, came, capacity], session: session} = context do
    pair = pair(title)

    session
    |> assert_has(
      "#{pair}[data-rsvps='#{rsvps}'][data-turnout='#{came}'][data-capacity='#{capacity}']"
    )
    |> assert_has("#{pair} .col.rsvps")
    |> assert_has("#{pair} .col.room")
    |> assert_has("#{pair} .cap[data-capacity='#{capacity}']")
    |> assert_has("#{pair} text", text: "#{rsvps}", exact: true)
    |> assert_has("#{pair} text.val", text: "#{came}", exact: true)

    context
  end

  step "the turnout bar for {string} reads {int} with {int} in the room and {int} on the call",
       %{args: [title, total, in_room, on_call], session: session} = context do
    pair = pair(title)

    session
    |> assert_has("#{pair}[data-turnout='#{total}']")
    |> assert_has("#{pair} .col.room[data-count='#{in_room}']")
    |> assert_has("#{pair} .col.call[data-count='#{on_call}']")
    |> assert_has("#{pair} text.val", text: "#{total}", exact: true)

    context
  end

  step "the turnout chart shows {string} with {int} RSVPs and an uncounted outline reading {string}",
       %{args: [title, rsvps, mark], session: session} = context do
    pair = pair(title)

    session
    |> assert_has("#{pair}[data-rsvps='#{rsvps}'][data-counted='false']")
    |> assert_has("#{pair} .col.none")
    |> assert_has("#{pair} text.val", text: mark, exact: true)

    context
  end

  step "the Next huddl panel says {string}", %{args: [line], session: session} = context do
    assert_has(session, "#next-huddl .stat .cmp", text: line)
    context
  end

  step "the Next huddl panel shows no expectation", %{session: session} = context do
    session
    |> assert_has("#next-huddl .stat .cmp", text: "published today", exact: true)
    |> refute_has("#next-huddl .stat", text: "expect about")

    context
  end

  defp pair(title) do
    huddl = find_huddl(title)
    "#turnout-chart .pair[data-huddl='#{huddl.id}']"
  end

  defp find_group(name) do
    Group |> Ash.Query.filter(name == ^name) |> Ash.read_one!(authorize?: false)
  end

  defp find_huddl(title) do
    Huddl |> Ash.Query.filter(title == ^title) |> Ash.read_one!(authorize?: false)
  end
end
