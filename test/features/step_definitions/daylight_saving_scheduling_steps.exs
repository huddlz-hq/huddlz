defmodule DaylightSavingSchedulingSteps do
  use Cucumber.StepDefinition

  import ExUnit.Assertions
  import Huddlz.Generator
  import Huddlz.Test.Helpers.Authentication
  import PhoenixTest

  @gap_date ~D[2027-03-14]
  @overlap_date ~D[2027-11-07]

  step "I schedule a huddl during a daylight-saving gap", %{conn: conn} = context do
    setup_schedule(context, conn, "Spring Forward Coffee")
  end

  step "I enter a nonexistent local time", context do
    session = enter_schedule(context.session, @gap_date, "02:30")
    Map.put(context, :session, session)
  end

  step "the time advances by the daylight-saving gap", context do
    assert_has(
      context.session,
      "#daylight-saving-resolution[data-resolution='gap']",
      text: "3:30 AM EDT"
    )

    context
  end

  step "I see the resolved local time before saving", context do
    assert_has(
      context.session,
      "#daylight-saving-resolution",
      text: "2:30 AM does not exist in New York. It will be scheduled at 3:30 AM EDT."
    )

    context
  end

  step "the saved UTC instant represents that resolved time", context do
    session = click_button(context.session, "Schedule huddl")
    huddl = scheduled_huddl(context)

    assert huddl.starts_at == ~U[2027-03-14 07:30:00Z]

    assert DateTime.shift_zone!(huddl.starts_at, "America/New_York") ==
             DateTime.new!(@gap_date, ~T[03:30:00], "America/New_York")

    Map.put(context, :session, session)
  end

  step "I schedule a huddl during a daylight-saving overlap", %{conn: conn} = context do
    setup_schedule(context, conn, "Fall Back Coffee")
  end

  step "I enter an ambiguous local time", context do
    session = enter_schedule(context.session, @overlap_date, "01:30")
    Map.put(context, :session, session)
  end

  step "the earlier occurrence is selected by default", context do
    assert_has(
      context.session,
      "#daylight-saving-resolution[data-resolution='ambiguous'] input[value='earlier'][checked]"
    )

    context
  end

  step "both occurrences are labeled with their abbreviations", context do
    context.session
    |> assert_has("label[for='ambiguous-time-earlier']", text: "1:30 AM EDT (earlier)")
    |> assert_has("label[for='ambiguous-time-later']", text: "1:30 AM EST (later)")

    context
  end

  step "I choose the later occurrence", context do
    session = choose(context.session, "1:30 AM EST (later)")
    Map.put(context, :session, session)
  end

  step "the saved UTC instant represents the later occurrence", context do
    session = click_button(context.session, "Schedule huddl")
    huddl = scheduled_huddl(context)

    assert huddl.starts_at == ~U[2027-11-07 06:30:00Z]
    assert DateTime.shift_zone!(huddl.starts_at, "America/New_York").zone_abbr == "EST"

    Map.put(context, :session, session)
  end

  defp setup_schedule(context, conn, title) do
    owner = generate(user(role: :user))
    group = generate(group(actor: owner, time_zone: "America/New_York"))

    session =
      conn
      |> login(owner)
      |> visit("/groups/#{group.slug}/huddlz/new")
      |> choose("Virtual")
      |> fill_in("Title", with: title)
      |> fill_in("Online link", with: "https://meet.example.com/dst")

    Map.merge(context, %{
      current_user: owner,
      group: group,
      huddl_title: title,
      session: session
    })
  end

  defp enter_schedule(session, date, time) do
    session
    |> fill_in("Date", with: Date.to_iso8601(date))
    |> fill_in("Start time", with: time)
  end

  defp scheduled_huddl(context) do
    context.group.id
    |> Huddlz.Communities.get_group_huddlz!(actor: context.current_user)
    |> Enum.find(&(&1.title == context.huddl_title))
  end
end
