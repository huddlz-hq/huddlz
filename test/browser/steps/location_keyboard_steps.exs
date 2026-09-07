defmodule BrowserLocationKeyboardSteps do
  use Cucumber.StepDefinition

  import ExUnit.Assertions
  import Huddlz.Generator
  import Huddlz.Test.MoxHelpers
  import PhoenixTest
  import PhoenixTest.Playwright, only: [add_session_cookie: 3, type: 3, press: 3, evaluate: 3]

  step "I have opened my profile in a browser", context do
    member = generate(user(role: :user))

    {:ok, token, _claims} =
      AshAuthentication.Jwt.token_for_user(member, %{}, domain: Huddlz.Accounts)

    stub_places_autocomplete(%{"saint" => [:saint_augustine]})
    stub_place_details(:defaults)

    conn =
      context.conn
      |> add_session_cookie(
        [
          value: %{
            user_token: token,
            live_socket_id: "users_sessions:#{Base.url_encode64(token)}"
          }
        ],
        HuddlzWeb.Endpoint.session_options()
      )
      |> visit("/profile")
      |> assert_has(".phx-connected")
      |> assert_has("h1", text: "Profile")
      |> evaluate(
        """
        (() => {
          window.prototypeSubmissions = 0;
          document.addEventListener('submit', () => window.prototypeSubmissions++, true);
          return true;
        })()
        """,
        fn installed -> assert installed end
      )

    Map.put(context, :conn, conn)
  end

  step "I type {string} into my home location", %{args: [query]} = context do
    conn = context.conn |> type("#profile-location-input", query) |> assert_has("[role='option']")
    Map.put(context, :conn, conn)
  end

  step "I highlight the first home location suggestion", context do
    conn =
      context.conn
      |> press("#profile-location-input", "ArrowDown")
      |> assert_has("#profile-location[data-has-highlight='true']")

    Map.put(context, :conn, conn)
  end

  step "I select the highlighted home location with Enter", context do
    Map.put(context, :conn, press(context.conn, "#profile-location-input", "Enter"))
  end

  step "my home location is {string}", %{args: [location]} = context do
    context.conn
    |> assert_has("[data-testid='location-selected']", text: location)
    |> assert_has("[role='alert']", text: "Home location updated")

    context
  end

  step "Enter did not submit a form", context do
    evaluate(context.conn, "window.prototypeSubmissions", fn count -> assert count == 0 end)
    context
  end
end
