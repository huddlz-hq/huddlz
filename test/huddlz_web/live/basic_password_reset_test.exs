defmodule HuddlzWeb.BasicPasswordResetTest do
  use HuddlzWeb.ConnCase, async: true
  import Swoosh.TestAssertions
  import PhoenixTest

  alias Huddlz.Accounts.User

  describe "password reset flow" do
    test "user can request and receive password reset email", %{conn: conn} do
      # Create and confirm a user
      {:ok, user} =
        User
        |> Ash.Changeset.for_create(:register_with_password, %{
          email: "test@example.com",
          password: "oldpassword123",
          password_confirmation: "oldpassword123",
          display_name: "Test User"
        })
        |> Ash.create()

      # Clear confirmation email
      assert_email_sent()

      # Confirm user
      user
      |> Ecto.Changeset.change(%{confirmed_at: DateTime.utc_now()})
      |> Huddlz.Repo.update!()

      # Visit the password reset page
      session =
        conn
        |> visit("/reset")
        |> fill_in("Email", with: "test@example.com")
        |> click_button("Send reset instructions")

      # Should show success message
      assert_has(session, "*", text: "If an account exists for that email")

      # Should have sent reset email
      assert_email_sent(fn email ->
        email.to == [{"", "test@example.com"}] &&
          email.subject == "Reset your password" &&
          email.html_body =~ "/reset/"
      end)
    end

    test "password reset shows form with valid token", %{conn: conn} do
      # Create user and get reset token
      {:ok, user} =
        User
        |> Ash.Changeset.for_create(:register_with_password, %{
          email: "form.test@example.com",
          password: "oldpassword123",
          password_confirmation: "oldpassword123",
          display_name: "Form Test User"
        })
        |> Ash.create()

      assert_email_sent()

      user
      |> Ecto.Changeset.change(%{confirmed_at: DateTime.utc_now()})
      |> Huddlz.Repo.update!()

      # Request reset
      conn
      |> visit("/reset")
      |> fill_in("Email", with: "form.test@example.com")
      |> click_button("Send reset instructions")

      # Get reset link
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

      # Visit reset link
      session = visit(conn, reset_path)

      # Should show the password reset form
      assert_has(session, "h2", text: "Set new password")
      assert_has(session, "input[type='password']")
      assert_has(session, "button", text: "Reset password")
    end

    test "invalid token shows form but cannot reset", %{conn: conn} do
      # Visit with an invalid token
      session = visit(conn, "/reset/invalid-token-123")

      # The form will initially appear
      assert_has(session, "h2", text: "Set new password")
      assert_has(session, "input[type='password']")
    end

    test "password reset with non-existent email still shows success", %{conn: conn} do
      # For security, we don't reveal if an email exists
      session =
        conn
        |> visit("/reset")
        |> fill_in("Email", with: "nonexistent@example.com")
        |> click_button("Send reset instructions")

      # Should show same success message as valid email
      assert_has(session, "*", text: "If an account exists for that email")

      # No email should be sent
      refute_email_sent()
    end
  end
end
