defmodule HuddlzWeb.PasswordResetFullFlowTest do
  use HuddlzWeb.ConnCase, async: true
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
          password_confirmation: "oldpassword123",
          display_name: "Reset Flow User"
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

    test "user can submit new password via reset form", %{conn: conn} do
      # Create and confirm a user
      {:ok, user} =
        User
        |> Ash.Changeset.for_create(:register_with_password, %{
          email: "submit.reset@example.com",
          password: "oldpassword123",
          password_confirmation: "oldpassword123",
          display_name: "Submit Reset User"
        })
        |> Ash.create()

      # Clear confirmation email
      assert_email_sent()

      # Confirm user
      user
      |> Ecto.Changeset.change(%{confirmed_at: DateTime.utc_now()})
      |> Huddlz.Repo.update!()

      # Request reset
      conn
      |> visit("/reset")
      |> within("#reset-password-form", fn session ->
        session
        |> fill_in("Email", with: "submit.reset@example.com")
        |> click_button("Send reset instructions")
      end)

      # Get the reset link from email
      reset_link =
        assert_email_sent(fn email ->
          if email.subject == "Reset your password" do
            case Regex.run(~r{<a href="([^"]+)">}, email.html_body) do
              [_, url] -> url
              _ -> false
            end
          else
            false
          end
        end)

      %{path: reset_path} = URI.parse(reset_link)

      # Visit the reset link and submit the new password
      session =
        conn
        |> visit(reset_path)
        |> within("#reset-password-confirm-form", fn s ->
          s
          |> fill_in("New password", with: "NewSecurePass456!")
          |> fill_in("Confirm new password", with: "NewSecurePass456!")
          |> click_button("Reset password")
        end)

      # Should see only the success message (no error flash)
      assert_has(session, "*", text: "Your password has successfully been reset")
      refute_has(session, "*", text: "Incorrect email or password")
    end

    test "user can sign in with new password after reset", %{conn: conn} do
      {:ok, user} =
        User
        |> Ash.Changeset.for_create(:register_with_password, %{
          email: "newpwd.test@example.com",
          password: "oldpassword123",
          password_confirmation: "oldpassword123",
          display_name: "New Pwd User"
        })
        |> Ash.create()

      assert_email_sent()

      user
      |> Ecto.Changeset.change(%{confirmed_at: DateTime.utc_now()})
      |> Huddlz.Repo.update!()

      # Request reset
      conn
      |> visit("/reset")
      |> within("#reset-password-form", fn session ->
        session
        |> fill_in("Email", with: "newpwd.test@example.com")
        |> click_button("Send reset instructions")
      end)

      # Get the reset link from email
      reset_link =
        assert_email_sent(fn email ->
          if email.subject == "Reset your password" do
            case Regex.run(~r{<a href="([^"]+)">}, email.html_body) do
              [_, url] -> url
              _ -> false
            end
          else
            false
          end
        end)

      %{path: reset_path} = URI.parse(reset_link)

      # Reset the password
      session =
        conn
        |> visit(reset_path)
        |> within("#reset-password-confirm-form", fn s ->
          s
          |> fill_in("New password", with: "BrandNewPass789!")
          |> fill_in("Confirm new password", with: "BrandNewPass789!")
          |> click_button("Reset password")
        end)

      # Verify the reset succeeded (controller processed it)
      assert_has(session, "*", text: "Your password has successfully been reset")

      # Sign in with the new password on a fresh connection
      session =
        conn
        |> visit("/sign-in")
        |> within("#password-sign-in-form", fn s ->
          s
          |> fill_in("Email", with: "newpwd.test@example.com")
          |> fill_in("Password", with: "BrandNewPass789!")
          |> click_button("Sign in")
        end)

      # Should be signed in with the new password
      assert_has(session, "a", text: "Sign Out")
    end

    test "invalid reset link shows error immediately", %{conn: conn} do
      # When visiting with an invalid token, the error is shown on mount
      session = visit(conn, "/reset/invalid-token-123")

      assert_has(session, "h2", text: "Invalid reset link")
      assert_has(session, "*", text: "This password reset link is invalid or has expired")
    end
  end
end
