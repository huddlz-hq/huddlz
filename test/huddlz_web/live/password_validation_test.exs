defmodule HuddlzWeb.PasswordValidationTest do
  use HuddlzWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Huddlz.Test.Helpers.Authentication
  import Swoosh.TestAssertions

  test "registration explains short and mismatched passwords accessibly", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/register")

    view
    |> form("#registration-form", %{
      "user" => %{
        "email" => unique_email("registration"),
        "display_name" => "Password Test",
        "password" => "short",
        "password_confirmation" => "different",
        "legal_acceptance" => "true"
      }
    })
    |> render_submit()

    assert has_element?(
             view,
             "#user_password[aria-invalid='true'][aria-describedby*='user_password-error-0']"
           )

    assert has_element?(
             view,
             "#user_password-error-0[role='alert']",
             "Password must be at least 8 characters."
           )

    assert has_element?(
             view,
             "#user_password_confirmation[aria-invalid='true'][aria-describedby*='user_password_confirmation-error-0']"
           )

    assert has_element?(
             view,
             "#user_password_confirmation-error-0[role='alert']",
             "Passwords do not match."
           )
  end

  test "registration gives each blank password field a friendly required message", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/register")

    view
    |> form("#registration-form", %{
      "user" => %{
        "email" => unique_email("blank-registration"),
        "display_name" => "Password Test",
        "password" => "",
        "password_confirmation" => "",
        "legal_acceptance" => "true"
      }
    })
    |> render_submit()

    assert has_element?(
             view,
             "#user_password-error-0[role='alert']",
             "Password is required."
           )

    assert has_element?(
             view,
             "#user_password_confirmation-error-0[role='alert']",
             "Password confirmation is required."
           )
  end

  test "profile password changes use the same friendly messages", %{conn: conn} do
    user =
      Huddlz.Generator.generate(
        Huddlz.Generator.user_with_password(
          email: unique_email("profile"),
          password: "OldPassword123!"
        )
      )

    {:ok, view, _html} =
      conn
      |> login(user)
      |> live(~p"/profile")

    view
    |> form("#password-form", %{
      "form" => %{
        "current_password" => "OldPassword123!",
        "password" => "short",
        "password_confirmation" => "different"
      }
    })
    |> render_submit()

    assert has_element?(
             view,
             "#form_password-error-0[role='alert']",
             "Password must be at least 8 characters."
           )

    assert has_element?(
             view,
             "#form_password_confirmation-error-0[role='alert']",
             "Passwords do not match."
           )
  end

  test "password reset uses the same friendly messages", %{conn: conn} do
    reset_path = reset_path_for(unique_email("reset"))
    {:ok, view, _html} = live(conn, reset_path)

    view
    |> form("#reset-password-confirm-form", %{
      "user" => %{
        "password" => "short",
        "password_confirmation" => "different"
      }
    })
    |> render_submit()

    assert has_element?(
             view,
             "#user-password-reset-password-with-token_password-error-0[role='alert']",
             "Password must be at least 8 characters."
           )

    assert has_element?(
             view,
             "#user-password-reset-password-with-token_password_confirmation-error-0[role='alert']",
             "Passwords do not match."
           )
  end

  defp unique_email(prefix) do
    "#{prefix}-#{System.unique_integer([:positive])}@example.com"
  end

  defp reset_path_for(email) do
    user =
      Huddlz.Generator.generate(
        Huddlz.Generator.user_with_password(
          email: email,
          password: "OldPassword123!"
        )
      )

    assert_email_sent()

    user
    |> Ecto.Changeset.change(%{confirmed_at: DateTime.utc_now()})
    |> Huddlz.Repo.update!()

    assert :ok =
             Huddlz.Accounts.User
             |> Ash.ActionInput.for_action(:request_password_reset_token, %{email: email})
             |> Ash.run_action()

    reset_link = assert_email_sent(&reset_link_from_email/1)

    URI.parse(reset_link).path
  end

  defp reset_link_from_email(%{subject: "Reset your password", html_body: body}) do
    case Regex.run(~r{<a href="([^"]+)">}, body) do
      [_, url] -> url
      _ -> false
    end
  end

  defp reset_link_from_email(_email), do: false
end
