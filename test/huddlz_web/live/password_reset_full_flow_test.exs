defmodule HuddlzWeb.PasswordResetFullFlowTest do
  use HuddlzWeb.ConnCase
  import Swoosh.TestAssertions
  import PhoenixTest

  alias Huddlz.Accounts.User

  describe "full password reset flow" do
    test "user can reset password through email link", %{conn: conn} do
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

      # Should be on the password reset confirmation page
      assert_has(session, "h2", text: "Set new password")

      # Fill in the new password form
      # Note: We can't test the actual form submission because PhoenixTest
      # doesn't execute JavaScript that handles phx-trigger-action
      # But we can verify the form is rendered correctly
      assert_has(session, "#reset-password-confirm-form")
      assert_has(session, "input[type='password'][name='user[password]']")
      assert_has(session, "input[type='password'][name='user[password_confirmation]']")
      assert_has(session, "button", text: "Reset password")

      # Test that we can submit directly to the controller endpoint
      # (simulating what the form would do with phx-trigger-action)
      conn =
        build_conn()
        |> Plug.Test.init_test_session(%{})
        |> post("/auth/user/password/reset", %{
          "user" => %{
            "reset_token" => URI.decode_www_form(reset_path) |> String.split("/") |> List.last(),
            "password" => "newpassword456",
            "password_confirmation" => "newpassword456"
          }
        })

      # Should redirect to home with success message
      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) == 
               "Your password has successfully been reset"

      # Verify password was changed by trying to sign in with new password
      user_result =
        User
        |> Ash.Query.for_read(:sign_in_with_password, %{
          email: "reset.flow@example.com",
          password: "newpassword456"
        })
        |> Ash.read_one()

      assert {:ok, _user} = user_result
    end

    test "invalid reset link shows form but fails on submission", %{conn: conn} do
      # When visiting with an invalid token, the form is shown
      # but submission will fail
      session = visit(conn, "/password-reset/invalid-token-123")
      
      # Should show the password reset form
      assert_has(session, "h2", text: "Set new password")
      
      # Try to submit with the invalid token
      conn =
        build_conn()
        |> Plug.Test.init_test_session(%{})
        |> post("/auth/user/password/reset", %{
          "user" => %{
            "reset_token" => "invalid-token-123",
            "password" => "newpassword456",
            "password_confirmation" => "newpassword456"
          }
        })

      # Should redirect to sign-in with error
      assert redirected_to(conn) == "/sign-in"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "Incorrect email or password"
    end
  end
end