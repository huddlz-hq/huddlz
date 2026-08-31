defmodule CalendarRelationshipMarkersSteps do
  use Cucumber.StepDefinition

  import Huddlz.Generator
  import Huddlz.Test.Helpers.Calendar
  import PhoenixTest

  alias Huddlz.Communities.HuddlAttendee

  step "I created a published huddl scheduled today", context do
    group =
      generate(
        group(
          owner_id: context.current_user.id,
          is_public: true,
          actor: context.current_user
        )
      )

    huddl = create_today_huddl(group, context.current_user, "Creator Calendar huddl")

    Map.merge(context, %{
      calendar_group: group,
      calendar_host: context.current_user,
      calendar_huddl: huddl
    })
  end

  step "I also have a confirmed RSVP for that huddl", context do
    create_rsvp!(context.calendar_huddl, context.current_user)
    context
  end

  step "I am waitlisted for a published huddl scheduled today", context do
    host = generate(user(role: :user))
    group = generate(group(owner_id: host.id, is_public: true, actor: host))
    huddl = create_today_huddl(group, host, "Waitlisted Calendar huddl")
    create_waitlist_entry!(huddl, context.current_user)

    Map.merge(context, %{
      calendar_group: group,
      calendar_host: host,
      calendar_huddl: huddl
    })
  end

  step "I organize a group", context do
    %{owner: owner, group: group} =
      create_calendar_member_group(
        member: context.current_user,
        role: :organizer,
        group: [is_public: true]
      )

    Map.merge(context, %{calendar_group: group, calendar_owner: owner})
  end

  step "another organizer created a published group huddl scheduled today", context do
    other_organizer = generate(user(role: :user))

    generate(
      group_member(
        group_id: context.calendar_group.id,
        user_id: other_organizer.id,
        role: :organizer,
        actor: context.calendar_owner
      )
    )

    huddl =
      create_today_huddl(
        context.calendar_group,
        other_organizer,
        "Other organizer Calendar huddl"
      )

    Map.merge(context, %{calendar_host: other_organizer, calendar_huddl: huddl})
  end

  step "I see the huddl once", context do
    assert_has(
      context.session,
      "#calendar-huddl-#{context.calendar_huddl.id}",
      count: 1
    )

    context
  end

  step "the huddl is not marked {string}", %{args: [marker]} = context do
    refute_has(
      context.session,
      "#calendar-huddl-#{context.calendar_huddl.id} [data-testid='calendar-relationship']",
      text: marker
    )

    context
  end

  defp create_rsvp!(huddl, user) do
    HuddlAttendee
    |> Ash.Changeset.for_create(:rsvp, %{huddl_id: huddl.id, user_id: user.id}, actor: user)
    |> Ash.create!()
  end

  defp create_waitlist_entry!(huddl, user) do
    HuddlAttendee
    |> Ash.Changeset.for_create(
      :join_waitlist,
      %{huddl_id: huddl.id, user_id: user.id},
      actor: user
    )
    |> Ash.create!()
  end
end
