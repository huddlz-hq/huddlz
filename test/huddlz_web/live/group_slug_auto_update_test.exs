defmodule HuddlzWeb.GroupSlugAutoUpdateTest do
  use HuddlzWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Huddlz.Generator

  describe "Group slug auto-generation" do
    setup do
      user = generate(user(role: :user))
      %{user: user}
    end

    test "slug preview updates as user types name", %{conn: conn, user: user} do
      {:ok, view, _html} =
        conn
        |> login(user)
        |> live(~p"/groups/new")

      # Type "A" - too short, slug not generated yet
      render_change(view, "validate", %{"form" => %{"name" => "A"}})
      assert has_element?(view, "#group-slug-preview", "URL: http://localhost:4002/groups/...")
      assert has_element?(view, "#form_name-error-0", "Must be between 3 and 100 characters")

      # Type "As" - still too short
      render_change(view, "validate", %{"form" => %{"name" => "As"}})
      assert has_element?(view, "#group-slug-preview", "URL: http://localhost:4002/groups/...")

      # Type "Ash" - now valid, slug should be generated
      render_change(view, "validate", %{"form" => %{"name" => "Ash"}})
      assert has_element?(view, "#group-slug-preview", "URL: http://localhost:4002/groups/ash")

      # Add space and more text
      render_change(view, "validate", %{"form" => %{"name" => "Ash Framework"}})

      assert has_element?(
               view,
               "#group-slug-preview",
               "URL: http://localhost:4002/groups/ash-framework"
             )
    end

    test "slug is generated from name and not directly editable", %{conn: conn, user: user} do
      {:ok, view, _html} =
        conn
        |> login(user)
        |> live(~p"/groups/new")

      # The form should not have a slug input field
      html = render(view)
      refute html =~ "name=\"form[slug]\""

      # But it should show the slug preview
      assert html =~ "/groups/..."

      # When we type a name, the preview should update
      html = render_change(view, "validate", %{"form" => %{"name" => "Test Group"}})
      assert html =~ "/groups/test-group"
    end

    test "slug preview handles special characters and spaces", %{conn: conn, user: user} do
      {:ok, view, _html} =
        conn
        |> login(user)
        |> live(~p"/groups/new")

      # Test various special characters
      html = render_change(view, "validate", %{"form" => %{"name" => "Hello, World!"}})
      assert html =~ "/groups/hello-world"

      html = render_change(view, "validate", %{"form" => %{"name" => "Test@#$%Group"}})
      assert html =~ "/groups/test-group"

      html = render_change(view, "validate", %{"form" => %{"name" => "Multiple   Spaces"}})
      assert html =~ "/groups/multiple-spaces"

      html = render_change(view, "validate", %{"form" => %{"name" => "Café & Restaurant"}})
      assert html =~ "/groups/cafe-restaurant"
    end

    test "empty name results in placeholder slug preview", %{conn: conn, user: user} do
      {:ok, view, _html} =
        conn
        |> login(user)
        |> live(~p"/groups/new")

      # Type something first
      render_change(view, "validate", %{"form" => %{"name" => "Something"}})

      # Then clear it - slug preview should show placeholder
      html = render_change(view, "validate", %{"form" => %{"name" => ""}})
      assert html =~ "/groups/..."
    end
  end
end
