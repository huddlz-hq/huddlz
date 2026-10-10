defmodule BrowserSignInReturnSteps do
  use Cucumber.StepDefinition

  import Huddlz.Generator
  import PhoenixTest
  import ExUnit.Assertions
  import Swoosh.TestAssertions, only: [set_swoosh_global: 0]
  alias PhoenixTest.Playwright.Case, as: BrowserCase

  step "I am signed out on a public group's second Past page", context do
    member =
      generate(user_with_password()) |> Ash.Seed.update!(%{confirmed_at: DateTime.utc_now()})

    owner = generate(user())
    group = generate(group(is_public: true, owner_id: owner.id, actor: owner))

    for day <- 1..12 do
      generate(
        past_huddl(
          group_id: group.id,
          creator_id: owner.id,
          title: "Return archive #{day}",
          starts_at: DateTime.add(DateTime.utc_now(), -day, :day),
          ends_at: DateTime.add(DateTime.utc_now(), -day, :day) |> DateTime.add(3600)
        )
      )
    end

    conn =
      context.conn
      |> visit("/groups/#{group.slug}?from=join_suggestion_notification")
      |> assert_has(".phx-connected")
      |> click_link("Past")
      |> click_link("a[aria-label='Next page']", "Next")
      |> assert_has("h3", text: "Return archive 11")
      |> refute_has("h3", text: "Return archive 1", exact: true)

    Map.merge(context, %{conn: conn, return_member: member, return_group: group})
  end

  step "I choose the header Sign in in a browser", context do
    Map.put(context, :conn, click_link(context.conn, ".content-actions a", "Sign in"))
  end

  step "I enter my return-visit credentials in a browser", context do
    conn =
      context.conn
      |> assert_has(".phx-connected")
      |> fill_in("Email", with: to_string(context.return_member.email))
      |> fill_in("Password", with: "Password123!")
      |> click_button("Sign in")

    Map.put(context, :conn, conn)
  end

  step "I see the same second Past page", context do
    context.conn
    |> assert_path("/groups/#{context.return_group.slug}",
      query_params: %{tab: "past", page: "2"}
    )
    |> assert_has("h3", text: "Return archive 11")
    |> assert_has("h3", text: "Return archive 12")
    |> refute_has("h3", text: "Return archive 1", exact: true)

    context
  end

  step "I am signed out reading Help in a connected browser", context do
    member =
      generate(user_with_password()) |> Ash.Seed.update!(%{confirmed_at: DateTime.utc_now()})

    conn = context.conn |> visit("/help") |> assert_has(".phx-connected")
    Map.merge(context, %{conn: conn, return_member: member})
  end

  step "I follow Help's API keys link", context do
    Map.put(
      context,
      :conn,
      context.conn
      |> click_link("#help-developers a", "Connect an agent")
      |> assert_has(".phx-connected")
      |> click_link("API keys")
    )
  end

  step "I arrive at my API keys", context do
    context.conn |> assert_path("/profile/api-keys") |> assert_has("h1", text: "API keys")
    context
  end

  step "I am signed out looking at a public huddl in a browser", context do
    set_swoosh_global()

    member =
      generate(user_with_password()) |> Ash.Seed.update!(%{confirmed_at: DateTime.utc_now()})

    owner = generate(user())
    group = generate(group(is_public: true, owner_id: owner.id, actor: owner))

    huddl =
      generate(huddl(group_id: group.id, creator_id: owner.id, actor: owner, is_private: false))

    path = "/groups/#{group.slug}/huddlz/#{huddl.id}"
    conn = context.conn |> visit(path) |> assert_has(".phx-connected")

    Map.merge(context, %{
      conn: conn,
      return_member: member,
      return_huddl: huddl,
      return_path: path
    })
  end

  step "I request and follow my password reset email in this browser", context do
    follow_reset_email(context, false)
  end

  step "I request a password reset and open its email in a fresh browser", context do
    follow_reset_email(context, true)
  end

  defp follow_reset_email(context, fresh_browser) do
    email = to_string(context.return_member.email)

    conn =
      context.conn
      |> click_link("Forgot your password?")
      |> assert_has("#reset-password-form")
      |> assert_has(".phx-connected")
      |> fill_in("Email", with: email)
      |> click_button("Send reset instructions")
      |> assert_has("h2", text: "Check your email")

    token =
      receive do
        {:email,
         %Swoosh.Email{subject: "Reset your password", to: [{_, ^email}], text_body: body}} ->
          [_, token] = Regex.run(~r{/reset/([A-Za-z0-9._~-]+)}, body)
          token
      after
        2000 -> flunk("No password reset email for the return visit")
      end

    conn =
      if fresh_browser do
        context
        |> Map.put(:module, __MODULE__)
        |> BrowserCase.do_setup()
        |> Keyword.fetch!(:conn)
      else
        conn
      end

    Map.put(context, :conn, visit(conn, "/reset/#{token}") |> assert_has(".phx-connected"))
  end

  step "I set a new password for the return visit in a browser", context do
    conn =
      context.conn
      |> fill_in("New password", with: "ChangedPassword123!")
      |> fill_in("Confirm new password", with: "ChangedPassword123!")
      |> click_button("Reset password")

    Map.put(context, :conn, conn)
  end

  step "I return to that huddl without reserving a spot in a browser", context do
    context.conn
    |> assert_path(context.return_path)
    |> assert_has("h1", text: context.return_huddl.title)
    |> assert_has("button", text: "RSVP")

    assert [] =
             Huddlz.Communities.check_user_rsvp!(context.return_huddl.id,
               actor: context.return_member
             )

    context
  end

  step "I retry after a wrong password and the sign-up and recovery detours", context do
    conn =
      context.conn
      |> assert_has("#password-sign-in-form")
      |> assert_has(".phx-connected")
      |> fill_in("Email", with: to_string(context.return_member.email))
      |> fill_in("Password", with: "IncorrectPassword123!")
      |> click_button("Sign in")
      |> assert_has("[role=alert]", text: "Incorrect email or password")
      |> click_link("Sign up")
      |> assert_has("#registration-form")
      |> click_link("Sign in")
      |> assert_has("#password-sign-in-form")
      |> click_link("Forgot your password?")
      |> assert_has("#reset-password-form")
      |> click_link("Back to sign in")
      |> assert_has("#password-sign-in-form")

    Map.put(context, :conn, conn)
  end

  step "I choose Sign in to join in a browser", context do
    Map.put(context, :conn, click_link(context.conn, "Sign in to join"))
  end

  step "I join the group after signing in", context do
    Map.put(context, :conn, click_button(context.conn, "Join group"))
  end

  step "my join retains its notification source", context do
    assert_has(context.conn, "button", text: "Leave group")

    membership =
      Huddlz.Communities.get_group_member!(context.return_group.id, context.return_member.id,
        actor: context.return_member
      )

    assert membership.join_source == :join_suggestion_notification
    context
  end

  step "I arrive at my normal agenda after recovery", context do
    context.conn |> assert_path("/agenda") |> assert_has("a", text: "Sign out")
    context
  end
end
