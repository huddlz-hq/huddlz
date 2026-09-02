defmodule EmptyCurrentDaySteps do
  use Cucumber.StepDefinition

  import ExUnit.Assertions
  import Huddlz.Generator
  import PhoenixTest

  alias Huddlz.Calendar.Clock

  step "I have no Calendar huddlz today", context do
    context
  end

  step "I have four future Calendar huddlz", %{current_user: user} = context do
    group = generate(group(owner_id: user.id, is_public: true, actor: user))
    tomorrow = Date.add(current_calendar_date(), 1)

    future_huddlz = [
      create_future_huddl(user, group, "Second future huddl", tomorrow, ~T[15:00:00]),
      create_future_huddl(user, group, "First future huddl", tomorrow, ~T[09:00:00]),
      create_future_huddl(
        user,
        group,
        "Third future huddl",
        Date.add(tomorrow, 1),
        ~T[08:00:00]
      ),
      create_future_huddl(
        user,
        group,
        "Fourth future huddl",
        Date.add(tomorrow, 2),
        ~T[08:00:00]
      )
    ]

    Map.put(context, :future_calendar_huddlz, future_huddlz)
  end

  step "I have no future Calendar huddlz", context do
    context
  end

  step "I see the shared empty current Day message", %{session: session} = context do
    assert_has(session, "#calendar-day-empty", text: "Nothing on your calendar today.")
    context
  end

  step "I see a {string} section", %{args: ["Coming up"], session: session} = context do
    assert_has(session, "#calendar-coming-up", text: "Coming up")
    context
  end

  step "I see the next three future huddlz in chronological order",
       %{session: session, future_calendar_huddlz: [second, first, third, _fourth]} = context do
    titles =
      session.view
      |> Phoenix.LiveViewTest.render()
      |> LazyHTML.from_fragment()
      |> LazyHTML.query("#calendar-coming-up-list .card-title")
      |> Enum.map(&LazyHTML.text/1)

    assert titles == [first.title, second.title, third.title]
    context
  end

  step "I do not see the fourth future huddl",
       %{session: session, future_calendar_huddlz: [_second, _first, _third, fourth]} = context do
    refute_has(session, "#calendar-coming-up", text: fourth.title)
    context
  end

  step "I do not see a {string} section", %{args: ["Coming up"], session: session} = context do
    refute_has(session, "#calendar-coming-up")
    context
  end

  step "I can navigate to Discover", %{session: session} = context do
    assert_has(session, "#calendar-discover-link[href='/discover']")
    session = click_link(session, "Discover huddlz")
    assert_path(session, "/discover")
    Map.put(context, :session, session)
  end

  defp create_future_huddl(user, group, title, date, time) do
    starts_at = DateTime.new!(date, time, "Etc/UTC")

    generate(
      past_huddl(
        group_id: group.id,
        creator_id: user.id,
        title: title,
        starts_at: starts_at,
        ends_at: DateTime.add(starts_at, 60, :minute),
        lifecycle_state: :published,
        is_private: false
      )
    )
  end

  defp current_calendar_date do
    Clock.utc_now()
    |> DateTime.shift_zone!("America/New_York")
    |> DateTime.to_date()
  end
end
