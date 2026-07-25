defmodule HuddlzWeb.AuthLive.EmailValidationTest do
  use HuddlzWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  describe "sign in email validation" do
    test "shows an inline error for a malformed email", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/sign-in")
      assert has_element?(view, "#password-sign-in-form[novalidate]")

      view
      |> form("#password-sign-in-form",
        user: %{email: "not-an-email", password: "Password123!"}
      )
      |> render_submit()

      assert_email_error(view, "#user_email", "Enter a valid email address.")
      assert has_element?(view, "#user_email[value='not-an-email']")
      refute has_element?(view, "#flash-error", "Incorrect email or password")
    end

    test "shows an inline error for a blank email", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/sign-in")

      view
      |> form("#password-sign-in-form", user: %{email: "", password: "Password123!"})
      |> render_submit()

      assert_email_error(view, "#user_email", "Email is required.")
    end

    test "keeps valid unknown emails behind the generic credentials message", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/sign-in")

      view
      |> form("#password-sign-in-form",
        user: %{email: "unknown@example.com", password: "Password123!"}
      )
      |> render_submit()

      assert has_element?(view, "#flash-error", "Incorrect email or password")
      refute has_element?(view, "#user_email[aria-invalid='true']")
    end
  end

  describe "registration email validation" do
    test "replaces the internal pattern message with friendly copy", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/register")
      assert has_element?(view, "#registration-form[novalidate]")

      view
      |> form("#registration-form",
        user: valid_registration_params(%{email: "not-an-email"})
      )
      |> render_submit()

      assert_email_error(view, "#user_email", "Enter a valid email address.")
      assert has_element?(view, "#user_email[value='not-an-email']")
      refute render(view) =~ "must match the pattern"
    end

    test "shows friendly required copy for a blank email", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/register")

      view
      |> form("#registration-form", user: valid_registration_params(%{email: ""}))
      |> render_submit()

      assert_email_error(view, "#user_email", "Email is required.")
    end
  end

  describe "password reset email validation" do
    test "keeps the form open with an inline error for a malformed email", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/reset")
      assert has_element?(view, "#reset-password-form[novalidate]")

      view
      |> form("#reset-password-form", form: %{email: "not-an-email"})
      |> render_submit()

      assert_email_error(view, "#form_email", "Enter a valid email address.")
      assert has_element?(view, "#form_email[value='not-an-email']")
      refute has_element?(view, ".auth-state", "Check your email")
    end

    test "keeps the form open with friendly required copy for a blank email", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/reset")

      view
      |> form("#reset-password-form", form: %{email: ""})
      |> render_submit()

      assert_email_error(view, "#form_email", "Email is required.")
      refute has_element?(view, ".auth-state", "Check your email")
    end
  end

  defp assert_email_error(view, input_selector, message) do
    assert has_element?(
             view,
             "#{input_selector}[aria-invalid='true'][aria-describedby$='-error-0']"
           )

    assert has_element?(view, "#{input_selector}-error-0", message)
  end

  defp valid_registration_params(overrides) do
    Map.merge(
      %{
        email: "person@example.com",
        display_name: "Email Test",
        password: "Password123!",
        password_confirmation: "Password123!",
        legal_acceptance: "true"
      },
      overrides
    )
  end
end
