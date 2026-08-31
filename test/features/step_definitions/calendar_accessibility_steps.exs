defmodule CalendarAccessibilitySteps do
  use Cucumber.StepDefinition

  import Huddlz.Generator
  import PhoenixTest

  step "I attended a past huddl named {string}",
       %{args: [title], current_user: attendee} = context do
    host = generate(user(role: :user))
    group = generate(group(owner_id: host.id, is_public: true, actor: host))
    starts_at = DateTime.utc_now() |> DateTime.add(-2, :day) |> DateTime.truncate(:second)

    huddl =
      generate(
        past_huddl(
          group_id: group.id,
          creator_id: host.id,
          is_private: false,
          title: title,
          starts_at: starts_at,
          ends_at: DateTime.add(starts_at, 1, :hour),
          actor: host
        )
      )

    huddl
    |> Ash.Changeset.for_update(:rsvp, %{}, actor: attendee)
    |> Ash.update!()

    Map.put(context, :calendar_huddl, huddl)
  end

  step "I open the calendar month containing that huddl",
       %{conn: conn, calendar_huddl: huddl} = context do
    date = DateTime.to_date(huddl.starts_at)
    month = :io_lib.format("~4..0B-~2..0B", [date.year, date.month]) |> IO.iodata_to_binary()

    session =
      visit(
        conn,
        "/calendar?view=month&month=#{month}&date=#{Date.to_iso8601(date)}"
      )

    Map.merge(context, %{conn: session, session: session})
  end

  step "the {string} calendar link should identify it as attended and past",
       %{args: [title], session: session, calendar_huddl: huddl} = context do
    assert_has(
      session,
      "#calendar-huddl-#{huddl.id} [data-testid='calendar-relationship']",
      text: "Attended · Past"
    )

    assert_has(session, "#calendar-huddl-#{huddl.id}", text: title)

    context
  end
end
