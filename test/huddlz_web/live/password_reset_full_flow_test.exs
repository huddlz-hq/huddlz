defmodule HuddlzWeb.PasswordResetFullFlowTest do
  use HuddlzWeb.ConnCase
  import Swoosh.TestAssertions
  import PhoenixTest

  alias Huddlz.Accounts.User

  describe "full password reset flow" do
    test "user can request password reset and see form", %{conn: conn} do
      # Create and confirm a user
      {:ok, user} =
        User
        |> Ash.Changeset.for_create(:register_with_password, %{
          email: "reset.flow@example.com",
          password: "oldpassword123",
          password_confirmation: "oldpassword123"
        })
        |> Ash.create()

      # Clear confirmation email
      assert_email_sent()

      # Confirm user
      user
      |> Ecto.Changeset.change(%{confirmed_at: DateTime.utc_now()})
      |> Huddlz.Repo.update!()

      # Start the password reset flow
      session =
        conn
        |> visit("/reset")
        |> within("#reset-password-form", fn session ->
          session
          |> fill_in("Email", with: "reset.flow@example.com")
          |> click_button("Send reset instructions")
        end)

      # Should see success message
      assert_has(session, "*", text: "If an account exists for that email")

      # Get the reset link from email
      reset_link =
        assert_email_sent(fn email ->
          if email.subject == "Reset your password" do
            # Extract the full URL from the email
            case Regex.run(~r{<a href="([^"]+)">}, email.html_body) do
              [_, url] -> url
              _ -> false
            end
          else
            false
          end
        end)

      refute reset_link == false, "Should find reset link in email"

      # Extract just the path from the full URL
      %{path: reset_path} = URI.parse(reset_link)

      # Visit the reset link
      session = visit(conn, reset_path)

      # Should be on our custom password reset form
      assert_has(session, "h2", text: "Set new password")
      assert_has(session, "button", text: "Reset password")

      # Our custom form uses LiveView instead of a form action
      assert_has(session, "form#reset-password-confirm-form")
      assert_has(session, "input[type='password']")
    end

    test "invalid reset link shows form initially", %{conn: conn} do
      # When visiting with an invalid token, the form is shown
      # but submission will fail
      session = visit(conn, "/reset/invalid-token-123")

      # The form will initially appear
      assert_has(session, "h2", text: "Set new password")

      # The form should have password fields
      assert_has(session, "input[type='password']")
      assert_has(session, "button", text: "Reset password")
    end
  end
end
