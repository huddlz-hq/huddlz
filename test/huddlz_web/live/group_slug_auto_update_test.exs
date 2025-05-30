defmodule HuddlzWeb.GroupSlugAutoUpdateTest do
  use HuddlzWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Huddlz.Generator

  describe "Group slug auto-generation" do
    setup do
      user = generate(user(role: :verified))
      %{user: user}
    end

    test "slug preview updates as user types name", %{conn: conn, user: user} do
      {:ok, view, _html} =
        conn
        |> login(user)
        |> live(~p"/groups/new")

      # Type "A" - slug preview should show "a"
      html = render_change(view, "validate", %{"form" => %{"name" => "A"}})
      assert html =~ "/groups/a"

      # Type "As" - slug preview should show "as"
      html = render_change(view, "validate", %{"form" => %{"name" => "As"}})
      assert html =~ "/groups/as"

      # Type "Ash" - slug preview should show "ash"
      html = render_change(view, "validate", %{"form" => %{"name" => "Ash"}})
      assert html =~ "/groups/ash"

      # Add space and more text
      html = render_change(view, "validate", %{"form" => %{"name" => "Ash Framework"}})
      assert html =~ "/groups/ash-framework"
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
