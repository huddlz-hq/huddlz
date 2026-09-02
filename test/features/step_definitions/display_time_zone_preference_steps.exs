defmodule CalendarTimeZonePreferenceSteps do
  use Cucumber.StepDefinition

  import Huddlz.Generator
  import Huddlz.Test.Helpers.Authentication
  import Phoenix.LiveViewTest, only: [put_connect_params: 2]
  import PhoenixTest

  alias Huddlz.Accounts

  step "my Calendar time-zone mode is Automatic", %{conn: conn} = context do
    user = generate(user(role: :user))
    user = Accounts.update_display_time_zone!(user, :automatic, nil, actor: user)

    context
    |> Map.put(:current_user, user)
    |> Map.put(:conn, login(conn, user))
  end

  step "I select Fixed {string}", %{args: [time_zone], session: session} = context do
    session = select(session, "Calendar time zone", option: time_zone)
    Map.put(context, :session, session)
  end

  step "Calendar uses {string}", %{args: [time_zone], session: session} = context do
    assert_has(session, "#calendar-time-zone[data-time-zone='#{time_zone}']")
    context
  end

  step "Automatic shows {string}", %{args: [time_zone], session: session} = context do
    assert_has(
      session,
      "#calendar-display-time-zone option[value='automatic']",
      text: "Automatic (#{time_zone})"
    )

    context
  end

  step "the choice remains after I sign in on another device", context do
    user = Accounts.get_by_email!(context.current_user.email)

    conn =
      Phoenix.ConnTest.build_conn()
      |> put_connect_params(%{"timezone" => "America/Los_Angeles"})
      |> login(user)

    session = visit(conn, "/calendar")
    assert_has(session, "#calendar-time-zone[data-time-zone='America/Denver']")

    Map.put(context, :session, session)
  end

  step "no valid browser or home Location time zone is available", %{conn: conn} = context do
    Map.put(context, :conn, put_connect_params(conn, %{"timezone" => "not/a-zone"}))
  end
end
