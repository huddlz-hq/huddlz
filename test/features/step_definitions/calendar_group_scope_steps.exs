defmodule CalendarGroupScopeSteps do
  use Cucumber.StepDefinition

  import Huddlz.Generator
  import PhoenixTest

  step "the calendar offers {string} and {string} scopes",
       %{args: [rsvps, groups], session: session} = context do
    session
    |> assert_has("#calendar-scope-mine", text: rsvps)
    |> assert_has("#calendar-scope-groups", text: groups)
    |> refute_has(".cal-scope", text: "My")

    context
  end

  step "I belong to {string}, which has scheduled {string}",
       %{args: [group_name, title], current_user: member} = context do
    host = generate(user(role: :user))
    group = generate(group(name: group_name, owner_id: host.id, is_public: true, actor: host))
    generate(group_member(group_id: group.id, user_id: member.id, role: "member", actor: host))
    schedule(group, host, title, 3)
    context
  end

  step "I am going to {string} with another group",
       %{args: [title], current_user: attendee} = context do
    host = generate(user(role: :user))
    group = generate(group(name: "PDX Rust", owner_id: host.id, is_public: true, actor: host))

    group
    |> schedule(host, title, 5)
    |> Ash.Changeset.for_update(:rsvp, %{}, actor: attendee)
    |> Ash.update!()

    context
  end

  step "a group I have not joined has scheduled {string}", %{args: [title]} = context do
    host = generate(user(role: :user))
    group = generate(group(name: "Strangers", owner_id: host.id, is_public: true, actor: host))
    schedule(group, host, title, 4)
    context
  end

  step "I switch to everything from my groups", %{session: session} = context do
    session = click_link(session, "#calendar-scope-groups", "Groups")
    Map.merge(context, %{conn: session, session: session})
  end

  step "the agenda lists {string} as going", %{args: [title], session: session} = context do
    assert_has(session, "#calendar-agenda .cal-agenda-entry[data-status=going] .cal-agenda-title",
      text: title
    )

    context
  end

  step "the agenda lists {string} without an RSVP status",
       %{args: [title], session: session} = context do
    session
    |> assert_has("#calendar-agenda .cal-agenda-entry[data-status=open] .cal-agenda-title",
      text: title
    )
    |> refute_has("#calendar-agenda .cal-agenda-entry[data-status=open] .cal-entry-status")

    context
  end

  step "{string}, a group I belong to, has scheduled {string} on day {int} of next month",
       %{args: [group_name, title, day], current_user: member} = context do
    host = generate(user(role: :user))
    group = generate(group(name: group_name, owner_id: host.id, is_public: true, actor: host))
    generate(group_member(group_id: group.id, user_id: member.id, role: "member", actor: host))
    schedule_on(group, host, title, %{next_month() | day: day})
    context
  end

  step "my RSVP {string} is on day {int} of next month",
       %{args: [title, day], current_user: attendee} = context do
    host = generate(user(role: :user))
    group = generate(group(owner_id: host.id, is_public: true, actor: host))

    group
    |> schedule_on(host, title, %{next_month() | day: day})
    |> Ash.Changeset.for_update(:rsvp, %{}, actor: attendee)
    |> Ash.update!()

    context
  end

  step "I open next month", %{conn: conn} = context do
    month = next_month()
    session = visit(conn, "/calendar/month?month=#{month.year}-#{pad(month.month)}")
    Map.merge(context, %{conn: session, session: session})
  end

  step "the scopes count {string} and {string}",
       %{args: [mine, groups], session: session} = context do
    session
    |> assert_has("#calendar-scope-mine", text: mine, exact: true)
    |> assert_has("#calendar-scope-groups", text: groups, exact: true)

    context
  end

  defp schedule_on(group, host, title, date) do
    generate(
      huddl(
        group_id: group.id,
        creator_id: host.id,
        is_private: false,
        title: title,
        date: date,
        actor: host
      )
    )
  end

  defp next_month do
    today = eastern_today()
    total = today.year * 12 + today.month
    Date.new!(div(total, 12), rem(total, 12) + 1, 1)
  end

  defp pad(n), do: String.pad_leading(Integer.to_string(n), 2, "0")

  defp schedule(group, host, title, days_ahead) do
    generate(
      huddl(
        group_id: group.id,
        creator_id: host.id,
        is_private: false,
        title: title,
        date: Date.add(eastern_today(), days_ahead),
        actor: host
      )
    )
  end
end
