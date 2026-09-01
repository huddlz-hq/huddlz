defmodule RecurringHuddlWallClockTimeSteps do
  use Cucumber.StepDefinition

  import ExUnit.Assertions
  import Huddlz.Generator
  import Huddlz.Test.Helpers.Authentication
  import PhoenixTest

  alias Huddlz.Communities
  alias Huddlz.Communities.Huddl
  alias Huddlz.Communities.Workers.RegenerateRecurringSeries

  @first_date ~D[2027-03-07]
  @repeat_until ~D[2027-03-22]

  step "I schedule a weekly huddl for 9:00 AM in {string}",
       %{args: [time_zone], conn: conn} = context do
    owner = generate(user(role: :user))
    attendee = generate(user(role: :user))
    group = generate(group(actor: owner, time_zone: time_zone, is_public: true))

    session =
      conn
      |> login(owner)
      |> visit("/groups/#{group.slug}/huddlz/new")
      |> choose("Virtual")
      |> fill_in("Title", with: "Weekly DST Coffee")
      |> fill_in("Date", with: Date.to_iso8601(@first_date))
      |> fill_in("Start time", with: "09:00")
      |> fill_in("Online link", with: "https://meet.example.com/dst-series")
      |> check("Recurring huddl")
      |> select("Frequency", option: "Weekly")
      |> fill_in("Repeat until", with: Date.to_iso8601(@repeat_until))
      |> click_button("Schedule huddl")

    [source] =
      Communities.get_group_huddlz!(group.id, actor: owner)
      |> Enum.filter(&(&1.title == "Weekly DST Coffee"))

    Map.merge(context, %{
      attendee: attendee,
      group: group,
      owner: owner,
      session: session,
      source: source,
      time_zone: time_zone
    })
  end

  step "the series crosses a daylight-saving transition", context do
    assert Date.compare(@first_date, ~D[2027-03-14]) == :lt
    assert Date.compare(@repeat_until, ~D[2027-03-14]) == :gt
    context
  end

  step "its occurrences are generated", context do
    :ok =
      RegenerateRecurringSeries.perform(%Oban.Job{
        args: %{"huddl_id" => context.source.id},
        attempt: 1,
        max_attempts: 3
      })

    occurrences =
      Huddl
      |> Ash.Query.for_read(:siblings_in_series, %{
        huddl_template_id: context.source.huddl_template_id,
        starting_after: context.source.starts_at
      })
      |> Ash.read!(authorize?: false)
      |> Enum.sort_by(& &1.starts_at, DateTime)

    Map.put(context, :occurrences, [context.source | occurrences])
  end

  step "every occurrence starts at 9:00 AM in {string}",
       %{args: [time_zone]} = context do
    assert Enum.map(context.occurrences, fn occurrence ->
             local = DateTime.shift_zone!(occurrence.starts_at, time_zone)
             {local.hour, local.minute}
           end) == [{9, 0}, {9, 0}, {9, 0}]

    context
  end

  step "the corresponding UTC time changes across the transition", context do
    assert Enum.map(context.occurrences, &{&1.starts_at.hour, &1.starts_at.minute}) ==
             [{14, 0}, {13, 0}, {13, 0}]

    context
  end

  step "each occurrence remains independently actionable", context do
    [_source, first_generated, second_generated] = context.occurrences

    Communities.rsvp_huddl!(first_generated, actor: context.attendee)

    assert [_rsvp] = Communities.check_user_rsvp!(first_generated.id, actor: context.attendee)
    assert [] = Communities.check_user_rsvp!(second_generated.id, actor: context.attendee)
    context
  end
end
