defmodule HuddlzWeb.LayoutsTest do
  use ExUnit.Case, async: true

  import Phoenix.Component
  import Phoenix.LiveViewTest

  alias HuddlzWeb.Layouts

  describe "app/1 notification navigation" do
    test "renders zero, one, and capped unread states in the persistent topbar" do
      zero = render_app(0)
      one = render_app(1)
      capped = render_app(100)

      assert has_selector?(zero, ~s|#notification-nav-link[aria-label="Notifications"]|)
      refute has_selector?(zero, "#notification-nav-badge")

      assert has_selector?(
               one,
               ~s|#notification-nav-link[aria-label="Notifications, 1 unread"]|
             )

      assert has_selector?(one, "#notification-nav-badge")
      assert badge_text(one) == "1"

      assert has_selector?(
               capped,
               ~s|#notification-nav-link[aria-label="Notifications, 100 unread"]|
             )

      assert badge_text(capped) == "99+"
    end

    test "keeps the badge in the responsive topbar rather than the desktop sidebar" do
      document = render_app(3)

      assert has_selector?(document, ".content-topbar #notification-nav-badge")
      refute has_selector?(document, ".sidebar #notification-nav-badge")
    end
  end

  defp render_app(unread_notification_count) do
    assigns = %{
      current_user: %{email: "person@example.com", display_name: "Test Person"},
      unread_notification_count: unread_notification_count
    }

    rendered_to_string(~H"""
    <Layouts.app
      flash={%{}}
      current_user={@current_user}
      unread_notification_count={@unread_notification_count}
    >
      Content
    </Layouts.app>
    """)
    |> LazyHTML.from_fragment()
  end

  defp badge_text(document) do
    document
    |> LazyHTML.query("#notification-nav-badge")
    |> LazyHTML.text()
    |> String.trim()
  end

  defp has_selector?(document, selector) do
    document
    |> LazyHTML.query(selector)
    |> Enum.empty?()
    |> Kernel.not()
  end
end
