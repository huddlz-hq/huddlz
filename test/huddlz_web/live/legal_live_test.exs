defmodule HuddlzWeb.LegalLiveTest do
  use HuddlzWeb.ConnCase, async: true

  test "renders the Terms of Service as a public, versioned document", %{conn: conn} do
    conn
    |> visit("/terms")
    |> assert_has("#legal-document h1", text: "huddlz Terms of Service")
    |> assert_has("#legal-document", text: "Version 2026-07-25")
    |> assert_has("#legal-document", text: "Real-world interactions and assumption of risk")
    |> assert_has(
      ".legal-document-nav a[aria-current='page'][href='/terms']",
      text: "Terms of Service"
    )
  end

  test "renders the Code of Conduct as a public document", %{conn: conn} do
    conn
    |> visit("/code-of-conduct")
    |> assert_has("#legal-document h1", text: "huddlz Code of Conduct")
    |> assert_has("#legal-document", text: "Unacceptable conduct")
    |> assert_has(
      ".legal-document-nav a[aria-current='page'][href='/code-of-conduct']",
      text: "Code of Conduct"
    )
  end

  test "renders the Privacy Policy as a public document", %{conn: conn} do
    conn
    |> visit("/privacy")
    |> assert_has("#legal-document h1", text: "huddlz Privacy Policy")
    |> assert_has("#legal-document", text: "Information we collect")
    |> assert_has(
      ".legal-document-nav a[aria-current='page'][href='/privacy']",
      text: "Privacy Policy"
    )
  end
end
