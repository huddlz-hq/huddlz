defmodule HistoricalPersonalHuddlParitySteps do
  use Cucumber.StepDefinition

  import ExUnit.Assertions
  import Huddlz.Generator
  import PhoenixTest

  alias Huddlz.Communities

  step "I hosted, attended, or was waitlisted for a past huddl", context do
    attendee = context.current_user
    host = generate(user(role: :user))
    group = generate(group(owner_id: host.id, is_public: true, actor: host))
    starts_at = past_start_time()

    huddl =
      generate(
        past_huddl(
          group_id: group.id,
          creator_id: host.id,
          is_private: false,
          title: "Historical Personal huddl",
          starts_at: starts_at,
          ends_at: DateTime.add(starts_at, 1, :hour)
        )
      )

    huddl
    |> Ash.Changeset.for_update(:rsvp, %{}, actor: attendee)
    |> Ash.update!()

    Map.merge(context, %{
      calendar_group: group,
      calendar_huddl: huddl,
      personal_relationship_marker: "Attended · Past"
    })
  end

  step "I navigate Calendar to the huddl's past date", context do
    date =
      context.calendar_huddl.starts_at
      |> DateTime.shift_zone!("America/New_York")
      |> DateTime.to_date()

    month = Calendar.strftime(date, "%Y-%m")

    session =
      visit(
        context.session,
        "/calendar?view=month&month=#{month}&date=#{Date.to_iso8601(date)}"
      )

    Map.put(context, :session, session)
  end

  step "I see its Personal relationship marker", context do
    assert_has(
      context.session,
      "#calendar-huddl-#{context.calendar_huddl.id} " <>
        "[data-testid='calendar-relationship']",
      text: context.personal_relationship_marker
    )

    context
  end

  step "the group has a past huddl that I never responded to", context do
    starts_at = past_start_time()

    huddl =
      generate(
        past_huddl(
          group_id: context.calendar_group.id,
          creator_id: context.calendar_owner.id,
          is_private: false,
          title: "Historical Group opportunity",
          starts_at: starts_at,
          ends_at: DateTime.add(starts_at, 1, :hour)
        )
      )

    assert Communities.check_user_rsvp!(huddl.id, actor: context.current_user) == []

    Map.put(context, :group_opportunity_huddl, huddl)
  end

  step "I visit the group and browse its huddlz", context do
    session = visit(context.session, "/groups/#{context.calendar_group.slug}")
    session = click_button(session, "Past")

    Map.put(context, :session, session)
  end

  step "I can find the past huddl using the group's existing behavior", context do
    assert_has(context.session, "h3", text: context.group_opportunity_huddl.title)
    context
  end

  defp past_start_time do
    DateTime.utc_now()
    |> DateTime.add(-14, :day)
    |> DateTime.truncate(:second)
  end
end
