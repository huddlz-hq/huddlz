defmodule GroupOpportunitiesInTodaySteps do
  use Cucumber.StepDefinition

  import ExUnit.Assertions
  import Huddlz.Generator
  import Huddlz.Test.Helpers.Authentication
  import PhoenixTest

  alias Huddlz.Communities

  step "I am an accepted member of a group", context do
    create_member_group(context, is_public: true)
  end

  step "I am an accepted member of a private group", context do
    create_member_group(context, is_public: false)
  end

  step "I have a pending invitation to a group", context do
    member = generate(user(role: :user))
    owner = generate(user(role: :user))
    group = generate(group(owner_id: owner.id, is_public: false, actor: owner))
    Communities.invite_to_group!(group.id, member.id, :member, actor: owner)

    context
    |> sign_in(member)
    |> Map.merge(%{calendar_group: group, calendar_owner: owner})
  end

  step "the group has a published huddl scheduled today", context do
    Map.put(context, :calendar_huddl, create_today_huddl(context, :published))
  end

  step "I am an accepted member of a group with a draft huddl scheduled today", context do
    context = create_member_group(context, is_public: true)
    Map.put(context, :draft_huddl, create_today_huddl(context, :draft))
  end

  step "another public group has a published huddl scheduled today", context do
    other_owner = generate(user(role: :user))

    other_group =
      generate(group(owner_id: other_owner.id, is_public: true, actor: other_owner))

    unrelated_huddl =
      create_today_huddl(
        %{calendar_group: other_group, calendar_owner: other_owner},
        :published
      )

    Map.merge(context, %{unrelated_group: other_group, unrelated_huddl: unrelated_huddl})
  end

  step "I have not responded to the huddl", context do
    assert_no_personal_relationship!(context.calendar_huddl, context.current_user)
    context
  end

  step "I have no relationship with that other group's huddl", context do
    assert_no_personal_relationship!(context.unrelated_huddl, context.current_user)

    refute Enum.any?(
             Communities.get_by_user!(actor: context.current_user),
             &(&1.group_id == context.unrelated_group.id)
           )

    context
  end

  step "I see the huddl in Today", context do
    assert_huddl_visible(context, context.calendar_huddl)
    context
  end

  step "the huddl has no Personal relationship marker", context do
    refute_has(
      context.session,
      "#calendar-huddl-#{context.calendar_huddl.id} [data-testid='calendar-relationship']"
    )

    context
  end

  step "I do not see the huddl in Today", context do
    refute_huddl_visible(context, context.calendar_huddl)
    context
  end

  step "I do not see the draft huddl", context do
    refute_huddl_visible(context, context.draft_huddl)
    context
  end

  step "I do not see the unrelated public huddl", context do
    refute_huddl_visible(context, context.unrelated_huddl)
    context
  end

  defp create_member_group(context, group_opts) do
    member = generate(user(role: :user))
    owner = generate(user(role: :user))

    {group, [_membership]} =
      generate_group_with_members(
        owner: owner,
        group: group_opts,
        members: [%{user: member, role: :member}]
      )

    context
    |> sign_in(member)
    |> Map.merge(%{calendar_group: group, calendar_owner: owner})
  end

  defp sign_in(context, user) do
    session = context.conn |> login(user) |> visit("/")
    Map.merge(context, %{current_user: user, session: session})
  end

  defp create_today_huddl(context, lifecycle_state) do
    starts_at = DateTime.new!(Date.utc_today(), ~T[12:00:00], "Etc/UTC")

    generate(
      past_huddl(
        group_id: context.calendar_group.id,
        creator_id: context.calendar_owner.id,
        title: "#{lifecycle_state} group huddl",
        starts_at: starts_at,
        ends_at: DateTime.add(starts_at, 60, :minute),
        lifecycle_state: lifecycle_state,
        is_private: !context.calendar_group.is_public
      )
    )
  end

  defp assert_no_personal_relationship!(huddl, user) do
    assert Communities.check_user_rsvp!(huddl.id, actor: user) == []
  end

  defp assert_huddl_visible(context, huddl) do
    assert_has(
      context.session,
      "#calendar-today-list #calendar-huddl-#{huddl.id}",
      text: huddl.title
    )
  end

  defp refute_huddl_visible(context, huddl) do
    refute_has(context.session, "#calendar-today-list #calendar-huddl-#{huddl.id}")
  end
end
