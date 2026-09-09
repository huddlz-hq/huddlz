defmodule CalendarGroupScopeSteps do
  use Cucumber.StepDefinition

  import Huddlz.Generator
  import PhoenixTest

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
    session = click_link(session, "#calendar-scope-groups", "My groups")
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
