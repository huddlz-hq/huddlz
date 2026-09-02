defmodule CalendarLifecycleAndMembershipChangesSteps do
  use Cucumber.StepDefinition

  import ExUnit.Assertions
  import Huddlz.Generator
  import Huddlz.Test.Helpers.Calendar
  import Huddlz.Test.Helpers.Authentication
  import PhoenixTest

  alias Huddlz.Calendar.Clock
  alias Huddlz.Communities
  alias Huddlz.Communities.GroupMember

  require Ash.Query

  step "I was going to a huddl scheduled today", context do
    host = generate(user(role: :user))
    group = generate(group(owner_id: host.id, is_public: true, actor: host))

    huddl =
      create_today_huddl(group, host, "Cancelled Personal huddl", full_today_range())

    Communities.rsvp_huddl!(huddl, actor: context.current_user)

    Map.merge(context, %{
      calendar_group: group,
      calendar_owner: host,
      calendar_huddl: huddl
    })
  end

  step "the huddl has been cancelled", context do
    huddl = Communities.cancel_huddl!(context.calendar_huddl, nil, actor: context.calendar_owner)
    Map.put(context, :calendar_huddl, huddl)
  end

  step "the group has a cancelled huddl scheduled today", context do
    huddl =
      create_today_huddl(
        context.calendar_group,
        context.calendar_owner,
        "Cancelled opportunity",
        full_today_range()
      )

    huddl = Communities.cancel_huddl!(huddl, nil, actor: context.calendar_owner)
    Map.put(context, :calendar_huddl, huddl)
  end

  step "I never responded to the huddl", context do
    assert Communities.check_user_rsvp!(context.calendar_huddl.id,
             actor: context.current_user
           ) == []

    context
  end

  step "I do not see the huddl", context do
    refute_has(context.session, "#calendar-huddl-#{context.calendar_huddl.id}")
    context
  end

  step "I left a public group", context do
    {context, membership} = create_member_group(context, is_public: true)

    uncommitted_huddl =
      create_today_huddl(
        context.calendar_group,
        context.calendar_owner,
        "Former group opportunity",
        full_today_range()
      )

    personal_huddl =
      create_today_huddl(
        context.calendar_group,
        context.calendar_owner,
        "Personal huddl after leaving",
        full_today_range()
      )

    Communities.rsvp_huddl!(personal_huddl, actor: context.current_user)

    context
    |> leave_group_and_sign_in(membership)
    |> Map.merge(%{uncommitted_huddl: uncommitted_huddl, personal_huddl: personal_huddl})
  end

  step "the group has one published huddl scheduled today that I never responded to", context do
    assert Communities.check_user_rsvp!(context.uncommitted_huddl.id,
             actor: context.current_user
           ) == []

    context
  end

  step "the group has another published huddl scheduled today that I am going to", context do
    assert [_rsvp] =
             Communities.check_user_rsvp!(context.personal_huddl.id,
               actor: context.current_user
             )

    context
  end

  step "I do not see the huddl I never responded to", context do
    refute_has(context.session, "#calendar-huddl-#{context.uncommitted_huddl.id}")
    context
  end

  step "I see the huddl I am going to marked {string}", %{args: [marker]} = context do
    assert_has(
      context.session,
      "#calendar-huddl-#{context.personal_huddl.id} [data-testid='calendar-relationship']",
      text: marker
    )

    context
  end

  step "I left a private group", context do
    {context, membership} = create_member_group(context, is_public: false)

    huddl =
      create_today_huddl(
        context.calendar_group,
        context.calendar_owner,
        "Former private group huddl",
        Keyword.put(full_today_range(), :is_private, true)
      )

    context
    |> leave_group_and_sign_in(membership)
    |> Map.put(:private_group_huddl, huddl)
  end

  step "I no longer have permission to view its huddlz", context do
    assert membership_for(context.calendar_group, context.current_user) == nil
    context
  end

  step "I do not see the private group's huddlz", context do
    refute_has(context.session, "#calendar-huddl-#{context.private_group_huddl.id}")
    context
  end

  defp create_member_group(context, group_opts) do
    %{member: member, owner: owner, group: group, membership: membership} =
      create_calendar_member_group(group: group_opts)

    context =
      Map.merge(context, %{
        current_user: member,
        calendar_group: group,
        calendar_owner: owner
      })

    {context, membership}
  end

  defp leave_group_and_sign_in(context, membership) do
    :ok = Ash.destroy!(membership, action: :leave_group, actor: context.current_user)
    session = context.conn |> login(context.current_user) |> visit("/")
    Map.put(context, :session, session)
  end

  defp full_today_range do
    date =
      Clock.utc_now()
      |> DateTime.shift_zone!("America/New_York")
      |> DateTime.to_date()

    starts_at =
      date
      |> DateTime.new!(~T[00:00:00], "America/New_York")
      |> DateTime.shift_zone!("Etc/UTC")

    [starts_at: starts_at, ends_at: DateTime.add(starts_at, 1, :day)]
  end

  defp membership_for(group, user) do
    GroupMember
    |> Ash.Query.filter(group_id == ^group.id and user_id == ^user.id)
    |> Ash.read_one!(authorize?: false)
  end
end
