defmodule GroupOpportunitiesInTodaySteps do
  use Cucumber.StepDefinition

  import ExUnit.Assertions
  import Huddlz.Generator
  import Huddlz.Test.Helpers.Calendar
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
    huddl =
      create_today_huddl(
        context.calendar_group,
        context.calendar_owner,
        "published group huddl"
      )

    Map.put(context, :calendar_huddl, huddl)
  end

  step "I am an accepted member of a group with a draft huddl scheduled today", context do
    context = create_member_group(context, is_public: true)

    huddl =
      create_today_huddl(
        context.calendar_group,
        context.calendar_owner,
        "draft group huddl",
        lifecycle_state: :draft
      )

    Map.put(context, :draft_huddl, huddl)
  end

  step "another public group has a published huddl scheduled today", context do
    other_owner = generate(user(role: :user))

    other_group =
      generate(group(owner_id: other_owner.id, is_public: true, actor: other_owner))

    unrelated_huddl =
      create_today_huddl(
        other_group,
        other_owner,
        "published group huddl"
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

  step "I see the huddl in Day", context do
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

  step "I do not see the huddl in Day", context do
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
    %{member: member, owner: owner, group: group} =
      create_calendar_member_group(group: group_opts)

    context
    |> sign_in(member)
    |> Map.merge(%{calendar_group: group, calendar_owner: owner})
  end

  defp sign_in(context, user) do
    session = context.conn |> login(user) |> visit("/")
    Map.merge(context, %{current_user: user, session: session})
  end

  defp assert_no_personal_relationship!(huddl, user) do
    assert Communities.check_user_rsvp!(huddl.id, actor: user) == []
  end

  defp assert_huddl_visible(context, huddl) do
    assert_has(
      context.session,
      "#calendar-day-list #calendar-huddl-#{huddl.id}",
      text: huddl.title
    )
  end

  defp refute_huddl_visible(context, huddl) do
    refute_has(context.session, "#calendar-day-list #calendar-huddl-#{huddl.id}")
  end
end
