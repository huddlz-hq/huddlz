defmodule BrowserSignInReturnSteps do
  use Cucumber.StepDefinition

  import Huddlz.Generator
  import PhoenixTest
  import ExUnit.Assertions
  import Swoosh.TestAssertions, only: [set_swoosh_global: 0]

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

  step "I choose the header Sign in in a browser", context do
    Map.put(context, :conn, click_link(context.conn, ".content-topbar a", "Sign in"))
  end

  step "I recover my password through its email in this browser", context do
    email = to_string(context.return_member.email)

    conn =
      context.conn
      |> click_link("Forgot your password?")
      |> assert_has("h1", text: "Reset your password")
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
      conn
      |> visit("/reset/#{token}")
      |> assert_has(".phx-connected")
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
end
