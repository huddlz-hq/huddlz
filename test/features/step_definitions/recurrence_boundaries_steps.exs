defmodule RecurrenceBoundariesSteps do
  use Cucumber.StepDefinition

  import ExUnit.Assertions
  import Huddlz.Generator
  import Huddlz.Test.Helpers.Authentication, only: [login: 2]
  import PhoenixTest

  alias Huddlz.Communities.{Huddl, HuddlTemplate}
  alias Huddlz.Communities.Workers.RegenerateRecurringSeries
  alias Huddlz.Notifications

  step "an organizer preparing a recurring huddl for a group with a member", context do
    owner = generate(user())
    member = generate(user())
    {group, _} = generate_group_with_members(owner: owner, members: [%{user: member}])

    session =
      context.conn
      |> login(owner)
      |> visit("/groups/#{group.slug}/huddlz/new")
      |> fill_in("Title", with: "Boundary validation")
      |> choose("Virtual")
      |> fill_in("Online link", with: "https://example.com/recurrence")
      |> fill_in("Date", with: "2030-09-08")
      |> fill_in("Start time", with: "23:30")
      |> check("Recurring huddl")

    {:ok, %{results: notifications}} =
      Notifications.list_for_user(actor: member, page: [limit: 100])

    Map.merge(context, %{
      owner: owner,
      member: member,
      group: group,
      session: session,
      notification_ids: Enum.map(notifications, & &1.id),
      template_count: Ash.count!(HuddlTemplate, authorize?: false),
      job_count: Huddlz.Repo.aggregate(Oban.Job, :count)
    })
  end

  step "the organizer schedules a {string} huddl ending before its first date",
       %{args: [cadence]} = context do
    session =
      context.session
      |> select("Frequency", option: cadence)
      |> fill_in("Repeat until", with: "2030-09-07")
      |> click_button("Schedule huddl")

    Map.put(context, :session, session)
  end

  step "the organizer has published the weekly series", context do
    context.session
    |> fill_in("Repeat until", with: "2030-09-23")
    |> click_button("Schedule huddl")
    |> assert_path("/groups/#{context.group.slug}")

    [huddl] = Ash.read!(Huddl, actor: context.owner)

    :ok =
      RegenerateRecurringSeries.perform(%Oban.Job{
        args: %{"huddl_id" => huddl.id},
        attempt: 1,
        max_attempts: 3
      })

    {:ok, %{results: notifications}} =
      Notifications.list_for_user(actor: context.member, page: [limit: 100])

    Map.merge(context, %{
      huddl: huddl,
      published_huddlz: Ash.read!(Huddl, actor: context.owner),
      template: Ash.get!(HuddlTemplate, huddl.huddl_template_id, authorize?: false),
      notification_ids: Enum.map(notifications, & &1.id),
      job_count: Huddlz.Repo.aggregate(Oban.Job, :count)
    })
  end

  step "the organizer ends the whole series before its first date", context do
    session =
      context.conn
      |> login(context.owner)
      |> visit("/groups/#{context.group.slug}/huddlz/#{context.huddl.id}/edit")
      |> click_button("Whole series")
      |> fill_in("Repeat until", with: "2030-09-07")
      |> click_button("Save changes")

    Map.put(context, :session, session)
  end

  step "the published series and member notifications should be unchanged", context do
    assert Ash.read!(Huddl, actor: context.owner) == context.published_huddlz

    assert Ash.get!(HuddlTemplate, context.huddl.huddl_template_id, authorize?: false) ==
             context.template

    assert Huddlz.Repo.aggregate(Oban.Job, :count) == context.job_count

    {:ok, %{results: notifications}} =
      Notifications.list_for_user(actor: context.member, page: [limit: 100])

    assert Enum.map(notifications, & &1.id) == context.notification_ids
    context
  end

  step "the organizer schedules the huddl ending on its first local date", context do
    session =
      context.session
      |> fill_in("Repeat until", with: "2030-09-08")
      |> click_button("Schedule huddl")
      |> assert_path("/groups/#{context.group.slug}")

    Map.put(context, :session, session)
  end

  step "the published huddl should start on that local date even though UTC is the next day",
       context do
    [huddl] = Ash.read!(Huddl, actor: context.owner)
    assert huddl.time_zone == "America/New_York"
    assert DateTime.to_date(huddl.starts_at) == ~D[2030-09-09]

    assert huddl.starts_at |> DateTime.shift_zone!(huddl.time_zone) |> DateTime.to_date() ==
             ~D[2030-09-08]

    context
  end

  step "the recurrence form should explain {string}", %{args: [message]} = context do
    assert_has(context.session, "#form_repeat_until-error-0", text: message)
    context
  end

  step "no huddl, series, or notification should have been created", context do
    assert Ash.read!(Huddl, actor: context.owner) == []
    assert Ash.count!(HuddlTemplate, authorize?: false) == context.template_count
    assert Huddlz.Repo.aggregate(Oban.Job, :count) == context.job_count

    {:ok, %{results: notifications}} =
      Notifications.list_for_user(actor: context.member, page: [limit: 100])

    assert Enum.map(notifications, & &1.id) == context.notification_ids
    context
  end
end
