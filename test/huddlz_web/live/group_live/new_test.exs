defmodule HuddlzWeb.GroupLive.NewTest do
  use HuddlzWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  describe "location errors" do
    setup %{conn: conn} do
      owner = generate(user(role: :user))
      %{conn: login(conn, owner)}
    end

    test "changing another field does not fault the untouched location", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/groups/new")

      # The location travels in a hidden input, so a change to any field
      # carries it along, blank; the browser marks the untouched textarea
      # unused, which this does by hand.
      html =
        render_change(view, "validate", %{
          "form" => %{"name" => "Founder Coffee", "location" => "", "_unused_description" => ""}
        })

      refute html =~ "is required"
    end

    test "submitting without a location shows the error", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/groups/new")

      html =
        view
        |> form("#group-form", form: %{name: "Founder Coffee", description: "Weekly coffee"})
        |> render_submit()

      assert html =~ "is required"
    end
  end
end
