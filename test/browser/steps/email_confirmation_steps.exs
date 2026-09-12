defmodule BrowserEmailConfirmationSteps do
  use Cucumber.StepDefinition

  import ExUnit.Assertions
  import Huddlz.Generator
  import Huddlz.Test.BrowserHelpers
  import PhoenixTest
  import Swoosh.TestAssertions

  step "I have hidden the reminder for my unconfirmed address in a browser", context do
    member = generate(user(confirmed_at: nil))
    set_swoosh_global()

    conn =
      context.conn
      |> sign_in(member)
      |> visit("/agenda")
      |> click_button("Hide until next time")
      |> visit("/profile")

    Map.merge(context, %{conn: conn, member: member})
  end

  step "I request confirmation from my profile", context do
    Map.put(context, :conn, click_button(context.conn, "Resend confirmation"))
  end

  step "a confirmation email is sent to my current address", context do
    conn = assert_has(context.conn, "[role=alert]", text: "Confirmation sent to")
    email = to_string(context.member.email)

    assert_email_sent(fn sent ->
      assert [{_, ^email}] = sent.to
      assert sent.subject == "Confirm your email address"
    end)

    Map.put(context, :conn, conn)
  end

  step "I can still save my display name", context do
    conn =
      context.conn
      |> fill_in("Display name", with: "Confirmation Reviewer")
      |> click_button("Save changes")
      |> assert_has("[role=alert]", text: "Display name updated successfully")
      |> visit("/profile")
      |> assert_has("input", label: "Display name", value: "Confirmation Reviewer")

    Map.put(context, :conn, conn)
  end
end
