defmodule HuddlzWeb.ProfileLiveTest do
  use HuddlzWeb.ConnCase

  import Phoenix.LiveViewTest
  import Huddlz.Test.Helpers.Authentication

  setup do
    user = create_user(%{display_name: "Test User"})
    %{user: user}
  end

  describe "Profile page" do
    test "requires authentication", %{conn: conn} do
      {:error, {:redirect, %{to: "/sign-in", flash: _}}} = live(conn, ~p"/profile")
    end

    test "displays user profile when authenticated", %{conn: conn, user: user} do
      conn = login(conn, user)
      {:ok, _view, html} = live(conn, ~p"/profile")

      assert html =~ "Profile Settings"
      assert html =~ "Display Name"
      assert html =~ user.display_name
      assert html =~ to_string(user.email)
    end

    test "shows the profile form", %{conn: conn, user: user} do
      conn = login(conn, user)
      {:ok, view, _html} = live(conn, ~p"/profile")

      assert has_element?(view, "form")
      assert has_element?(view, "input[name=\"form[display_name]\"]")
      assert has_element?(view, "button[type=\"submit\"]", "Save Changes")
    end

    test "updates display name successfully", %{conn: conn, user: user} do
      conn = login(conn, user)
      {:ok, view, _html} = live(conn, ~p"/profile")

      new_name = "Updated Test Name"

      view
      |> form("form[phx-submit=\"save\"]", %{"form[display_name]" => new_name})
      |> render_submit()

      # Check flash message appears
      assert render(view) =~ "Display name updated successfully"

      # Check the form now shows the new name
      assert has_element?(view, "input[name=\"form[display_name]\"][value=\"#{new_name}\"]")
    end

    test "validates display name length", %{conn: conn, user: user} do
      conn = login(conn, user)
      {:ok, view, _html} = live(conn, ~p"/profile")

      # Test empty (not allowed)
      view
      |> form("form[phx-submit=\"save\"]", %{"form[display_name]" => ""})
      |> render_submit()

      assert render(view) =~ "Failed to update display name"

      # Test too long (> 30 chars)
      long_name = String.duplicate("a", 31)

      view
      |> form("form[phx-submit=\"save\"]", %{"form[display_name]" => long_name})
      |> render_submit()

      assert render(view) =~ "Failed to update display name"

      # Test single character (should be allowed)
      view
      |> form("form[phx-submit=\"save\"]", %{"form[display_name]" => "A"})
      |> render_submit()

      assert render(view) =~ "Display name updated successfully"
    end

    test "display name validation on change", %{conn: conn, user: user} do
      conn = login(conn, user)
      {:ok, view, _html} = live(conn, ~p"/profile")

      # Test validation feedback on change
      view
      |> form("form[phx-change=\"validate\"]", %{"form[display_name]" => ""})
      |> render_change()

      # The form should still be present and functional
      assert has_element?(view, "form")
    end
  end
end
