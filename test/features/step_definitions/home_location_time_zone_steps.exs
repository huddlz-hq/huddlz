defmodule HomeLocationTimeZoneSteps do
  use Cucumber.StepDefinition

  import Huddlz.Generator
  import Huddlz.Test.Helpers.Authentication
  import Huddlz.Test.Helpers.LocationSelection
  import ExUnit.Assertions
  import Phoenix.LiveViewTest, only: [put_connect_params: 2]
  import PhoenixTest

  alias Huddlz.Accounts

  step "my browser does not provide a valid time zone", %{conn: conn} = context do
    user = generate(user(role: :user))
    user = Accounts.update_display_time_zone!(user, :automatic, nil, actor: user)

    context
    |> Map.put(:current_user, user)
    |> Map.put(:conn, conn |> put_connect_params(%{"timezone" => "not/a-zone"}) |> login(user))
  end

  step "my saved home location resolves to {string}",
       %{args: [time_zone], conn: conn} = context do
    Mox.expect(Huddlz.MockLocationTimeZone, :resolve, fn 41.88, -87.63 ->
      {:ok, time_zone}
    end)

    session = visit(conn, "/profile")
    Mox.allow(Huddlz.MockLocationTimeZone, self(), session.view.pid)

    session =
      select_location(session,
        id: "profile-location",
        display_text: "Chicago, IL, USA",
        latitude: 41.88,
        longitude: -87.63
      )

    Map.put(context, :session, session)
  end

  step "I visit Calendar in Automatic mode", context do
    session = visit(context.session || context.conn, "/calendar")
    Map.put(context, :session, session)
  end

  step "I select a home location whose time zone cannot be resolved", %{conn: conn} = context do
    user = generate(user(role: :user))
    session = conn |> login(user) |> visit("/profile")

    Mox.expect(Huddlz.MockLocationTimeZone, :resolve, fn latitude, longitude ->
      assert latitude == 0.0
      assert longitude == 0.0
      {:error, :not_found}
    end)

    Mox.allow(Huddlz.MockLocationTimeZone, self(), session.view.pid)

    context
    |> Map.put(:current_user, user)
    |> Map.put(:session, session)
    |> Map.put(:pending_location,
      id: "profile-location",
      display_text: "Unknown place",
      latitude: 0.0,
      longitude: 0.0
    )
  end

  step "I save my profile", context do
    session = select_location(context.session, context.pending_location)
    Map.put(context, :session, session)
  end

  step "I am asked to choose a valid time zone", context do
    context.session
    |> assert_has("#home-location-time-zone-form")
    |> assert_has("#home-location-time-zone-error", text: "Choose a valid time zone")

    context
  end

  step "the home location is not saved without one", context do
    user = Accounts.get_by_email!(context.current_user.email)

    assert is_nil(user.home_location)
    assert is_nil(user.home_time_zone)

    context
  end
end
