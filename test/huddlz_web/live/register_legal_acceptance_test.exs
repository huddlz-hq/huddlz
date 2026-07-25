defmodule HuddlzWeb.RegisterLegalAcceptanceTest do
  use HuddlzWeb.ConnCase, async: true

  alias Huddlz.Accounts.User
  alias Huddlz.Legal

  test "registration presents conspicuous links to the legal documents", %{conn: conn} do
    conn
    |> visit("/register")
    |> assert_has("#registration-form a[href='/terms'][target='_blank']")
    |> assert_has("#registration-form a[href='/code-of-conduct'][target='_blank']")
    |> assert_has("#registration-form a[href='/privacy'][target='_blank']")
    |> assert_has(
      "label[for='user_legal_acceptance']",
      text: "I agree to the Terms of Service and Code of Conduct"
    )
  end

  test "registration is rejected until legal acceptance is checked", %{conn: conn} do
    email = unique_email("no-acceptance")

    conn
    |> visit("/register")
    |> fill_registration_form(email)
    |> click_button("Create account")
    |> assert_has(
      "#registration-form .form-error",
      text: "You must accept the Terms of Service and Code of Conduct"
    )

    refute registered_user(email)
  end

  test "registration records the accepted document version and timestamp", %{conn: conn} do
    email = unique_email("accepted")

    conn
    |> visit("/register")
    |> fill_registration_form(email)
    |> check(Legal.acceptance_text())
    |> click_button("Create account")

    user = registered_user(email)

    assert user.legal_documents_version == Legal.current_version()
    assert %DateTime{} = user.legal_terms_accepted_at
  end

  defp fill_registration_form(session, email) do
    session
    |> fill_in("Email", with: email)
    |> fill_in("Display Name", with: "Legal Test User")
    |> fill_in("Password", with: "Password123!")
    |> fill_in("Confirm Password", with: "Password123!")
  end

  defp registered_user(email) do
    User
    |> Ash.Query.for_read(:get_by_email, %{email: email})
    |> Ash.read_one!(authorize?: false)
  end

  defp unique_email(prefix) do
    "#{prefix}-#{System.unique_integer([:positive])}@example.com"
  end
end
