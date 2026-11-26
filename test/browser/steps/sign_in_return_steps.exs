defmodule BrowserSignInReturnSteps do
  use Cucumber.StepDefinition
  use Fluffy.Assert

  import Fluffy, except: [step: 3]
  import Fluffy.Locator
  import Huddlz.Generator
  import Swoosh.TestAssertions, only: [set_swoosh_global: 0]

  step "I am signed out looking at a public huddl in a browser", %{session: session} do
    set_swoosh_global()

    member =
      generate(user_with_password()) |> Ash.Seed.update!(%{confirmed_at: DateTime.utc_now()})

    owner = generate(user())
    group = generate(group(is_public: true, owner_id: owner.id, actor: owner))

    huddl =
      generate(huddl(group_id: group.id, creator_id: owner.id, actor: owner, is_private: false))

    path = "/groups/#{group.slug}/huddlz/#{huddl.id}"
    visit(session, path)

    %{return_member: member, return_huddl: huddl, return_path: path}
  end

  step "I choose the header Sign in in a browser", %{session: session} do
    click(session, by_role(by_css(".content-topbar"), :link, name: "Sign in"))
    :ok
  end

  step "I recover my password through its email in this browser",
       %{session: session} = context do
    email = to_string(context.return_member.email)

    session
    |> click(by_role(:link, name: "Forgot your password?"))
    |> assert_has(by_role(:heading, level: 1, name: "Reset your password"))
    |> fill(by_label("Email", exact: true), email)
    |> click(by_role(:button, name: "Send reset instructions"))
    |> assert_has(by_role(:heading, level: 2, name: "Check your email"))

    token =
      receive do
        {:email,
         %Swoosh.Email{subject: "Reset your password", to: [{_, ^email}], text_body: body}} ->
          [_, token] = Regex.run(~r{/reset/([A-Za-z0-9._~-]+)}, body)
          token
      after
        2000 -> flunk("No password reset email for the return visit")
      end

    session
    |> visit("/reset/#{token}")
    |> fill(by_label("New password", exact: true), "ChangedPassword123!")
    |> fill(by_label("Confirm new password", exact: true), "ChangedPassword123!")
    |> click(by_role(:button, name: "Reset password"))

    :ok
  end

  step "I return to that huddl without reserving a spot in a browser",
       %{session: session} = context do
    session
    |> assert(page_url(&(&1.path == context.return_path)))
    |> assert_has(by_role(:heading, level: 1, name: context.return_huddl.title))
    |> assert_has(by_role(:button, name: "RSVP"))

    assert [] =
             Huddlz.Communities.check_user_rsvp!(context.return_huddl.id,
               actor: context.return_member
             )

    :ok
  end
end
