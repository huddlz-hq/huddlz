defmodule BrowserEmailConfirmationSteps do
  use Cucumber.StepDefinition
  use Fluffy.Assert

  import Fluffy, except: [step: 3]
  import Fluffy.Locator
  import Huddlz.Generator
  import Huddlz.Test.BrowserHelpers
  import Swoosh.TestAssertions

  step "I have hidden the reminder for my unconfirmed address in a browser", %{session: session} do
    member = generate(user(confirmed_at: nil))
    set_swoosh_global()

    session
    |> sign_in(member)
    |> visit("/agenda")
    |> click(by_role(:button, name: "Hide until next time"))
    |> visit("/profile")

    %{member: member}
  end

  step "I request confirmation from my profile", %{session: session} do
    click(session, by_role(:button, name: "Resend confirmation"))
    :ok
  end

  step "a confirmation email is sent to my current address", %{session: session} = context do
    assert(session, visible(alert("Confirmation sent to")))
    email = to_string(context.member.email)

    assert_email_sent(fn sent ->
      assert [{_, ^email}] = sent.to
      assert sent.subject == "Confirm your email address"
    end)

    :ok
  end

  step "I can still save my display name", %{session: session} do
    session
    |> assert(visible(by_css("body .phx-connected") |> first()))
    |> fill(by_label("Display name", exact: true), "Confirmation Reviewer")
    |> click(by_role(:button, name: "Save changes"))
    |> assert(visible(alert("Display name updated successfully")))
    |> visit("/profile")
    |> assert(value(by_label("Display name", exact: true), "Confirmation Reviewer"))

    :ok
  end

  defp alert(text), do: by_role(:alert) |> filter(has_text: text)
end
