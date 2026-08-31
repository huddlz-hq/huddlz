defmodule CalendarRelationshipMarkersSteps do
  use Cucumber.StepDefinition

  import Huddlz.Generator
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
    owner = generate(user(role: :user))

    {group, [_membership]} =
      generate_group_with_members(
        owner: owner,
        group: [is_public: true],
        members: [%{user: context.current_user, role: :organizer}]
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
      "#calendar-today-list #calendar-huddl-#{context.calendar_huddl.id}",
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

  defp create_today_huddl(group, creator, title) do
    starts_at = DateTime.new!(Date.utc_today(), ~T[12:00:00], "Etc/UTC")

    generate(
      past_huddl(
        group_id: group.id,
        creator_id: creator.id,
        title: title,
        starts_at: starts_at,
        ends_at: DateTime.add(starts_at, 60, :minute),
        lifecycle_state: :published,
        is_private: false
      )
    )
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
