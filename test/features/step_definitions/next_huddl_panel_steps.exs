defmodule NextHuddlPanelSteps do
  use Cucumber.StepDefinition

  import Ecto.Query, only: [from: 2]
  import ExUnit.Assertions
  import Huddlz.Generator
  import PhoenixTest

  require Ash.Query

  alias Huddlz.Communities.{Group, Huddl, HuddlAttendee}
  alias Huddlz.Repo

  @day 86_400

  step "the huddl {string} in {string} starts in {int} days with room for {int} and {int} RSVPs",
       %{args: [title, group_name, days, capacity, rsvps]} = context do
    group = find_group(group_name)
    host = Ash.get!(Huddlz.Accounts.User, group.owner_id, authorize?: false)

    huddl =
      generate(
        huddl(
          title: title,
          group_id: group.id,
          creator_id: host.id,
          is_private: false,
          max_attendees: capacity,
          date: Date.add(eastern_today(), days),
          actor: host
        )
      )

    # The host is RSVPed on creation; top up to the asked-for count.
    standing = huddl |> Ash.load!(:rsvp_count, authorize?: false) |> Map.fetch!(:rsvp_count)

    for _ <- 1..(rsvps - standing)//1 do
      attendee = generate(user(role: :user))

      Ash.Seed.seed!(HuddlAttendee, %{
        huddl_id: huddl.id,
        user_id: attendee.id,
        rsvped_at: DateTime.utc_now()
      })
    end

    context
  end

  step "{string} was published {int} days ago and its RSVPs came in evenly since",
       %{args: [title, days]} = context do
    huddl = find_huddl(title)
    now = DateTime.utc_now()
    published_at = DateTime.add(now, -days * @day, :second)

    Repo.update_all(from(h in "huddlz", where: h.id == type(^huddl.id, :binary_id)),
      set: [published_at: published_at]
    )

    rows =
      HuddlAttendee
      |> Ash.Query.filter(huddl_id == ^huddl.id and is_nil(waitlisted_at))
      |> Ash.Query.sort(rsvped_at: :asc)
      |> Ash.read!(authorize?: false)

    # First RSVP at publish, the last one an hour ago, the rest spread between.
    span = DateTime.diff(now, published_at, :second) - 3600
    last = max(length(rows) - 1, 1)

    rows
    |> Enum.with_index()
    |> Enum.each(fn {row, i} ->
      at = DateTime.add(published_at, div(span * i, last), :second)

      Repo.update_all(from(a in "huddl_attendees", where: a.id == type(^row.id, :binary_id)),
        set: [rsvped_at: at]
      )
    end)

    context
  end

  step "{string} has {int} past huddlz", %{args: [group_name, count]} = context do
    group = find_group(group_name)
    now = DateTime.utc_now()

    for n <- 1..count//1 do
      starts_at = DateTime.add(now, -(n * 7) * @day, :second)
      published_at = DateTime.add(starts_at, -14 * @day, :second)

      huddl =
        generate(
          past_huddl(
            title: "Past huddl #{n}",
            group_id: group.id,
            creator_id: group.owner_id,
            is_private: false,
            starts_at: starts_at,
            ends_at: DateTime.add(starts_at, 2 * 3600, :second),
            published_at: published_at
          )
        )

      # Three RSVPs, one a day, starting the day after publish.
      for d <- 1..3 do
        attendee = generate(user(role: :user))

        Ash.Seed.seed!(HuddlAttendee, %{
          huddl_id: huddl.id,
          user_id: attendee.id,
          rsvped_at: DateTime.add(published_at, d * @day, :second)
        })
      end
    end

    context
  end

  step "the next huddl panel names {string}", %{args: [title], session: session} = context do
    assert_has(session, "#next-huddl .panel-head", text: title)
    context
  end

  step "the next huddl panel shows {string}", %{args: [figure], session: session} = context do
    assert_has(session, "#next-huddl .stat .big", text: figure, exact: true)
    context
  end

  step "the signup curve has one point per day for {int} days and ends at {int}",
       %{args: [days, last], session: session} = context do
    assert_has(session, "#next-huddl-curve[data-days='#{days}'][data-points$=',#{last}']")
    context
  end

  step "the signup chart marks the capacity of {int}",
       %{args: [capacity], session: session} = context do
    assert_has(session, "#next-huddl-capacity[data-capacity='#{capacity}']")
    context
  end

  step "the panel also draws the group's typical curve", %{session: session} = context do
    assert_has(session, "#next-huddl-curve[data-points]")
    assert_has(session, "#next-huddl-typical[data-points]")
    context
  end

  step "only the huddl's own curve is drawn", %{session: session} = context do
    session
    |> assert_has("#next-huddl-curve[data-points]")
    |> refute_has("#next-huddl-typical")

    context
  end

  step "the signup curve reads:", %{session: session} = context do
    assert_curve(session, "next-huddl-curve", context.datatable.raw)
    context
  end

  step "the typical curve reads:", %{session: session} = context do
    assert_curve(session, "next-huddl-typical", context.datatable.raw)
    context
  end

  step "the panel lists the other upcoming huddl {string}",
       %{args: [line], session: session} = context do
    assert_has(session, "#next-huddl-others li", text: line, exact: true)
    context
  end

  step "the panel invites me to create a huddl", %{session: session} = context do
    session
    |> assert_has("#next-huddl", text: "Nothing on the calendar yet")
    |> assert_has("#next-huddl a", text: "Create a huddl")

    context
  end

  # The line's points read back from its data attribute, one per day since
  # publish; "today" is the last.
  defp assert_curve(session, id, rows) do
    [points] =
      session.view
      |> Phoenix.LiveViewTest.render()
      |> LazyHTML.from_document()
      |> LazyHTML.query("##{id}")
      |> LazyHTML.attribute("data-points")

    points = String.split(points, ",")

    for [day, expected] <- rows do
      actual = Enum.at(points, day_index(day, points))

      assert actual == expected,
             "expected #{day} to read #{expected}, got #{actual} in #{Enum.join(points, ",")}"
    end
  end

  defp day_index("today", points), do: length(points) - 1
  defp day_index("day " <> day, _points), do: String.to_integer(day)

  defp find_group(name) do
    Group |> Ash.Query.filter(name == ^name) |> Ash.read_one!(authorize?: false)
  end

  defp find_huddl(title) do
    Huddl |> Ash.Query.filter(title == ^title) |> Ash.read_one!(authorize?: false)
  end
end
