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

      assert zero =~ ~s|id="notification-nav-link"|
      assert zero =~ ~s|aria-label="Notifications"|
      refute zero =~ ~s|id="notification-nav-badge"|

      assert one =~ ~s|aria-label="Notifications, 1 unread"|
      assert one =~ ~s|id="notification-nav-badge"|
      assert badge_text(one) == "1"

      assert capped =~ ~s|aria-label="Notifications, 100 unread"|
      assert badge_text(capped) == "99+"
    end

    test "keeps the badge in the responsive topbar rather than the desktop sidebar" do
      html = render_app(3)
      {:ok, document} = Floki.parse_document(html)

      assert Floki.find(document, ".content-topbar #notification-nav-badge") != []
      assert Floki.find(document, ".sidebar #notification-nav-badge") == []
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
  end

  defp badge_text(html) do
    {:ok, document} = Floki.parse_document(html)

    document
    |> Floki.find("#notification-nav-badge")
    |> Floki.text()
    |> String.trim()
  end
end
