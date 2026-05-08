defmodule HuddlzWeb.CoreComponentsTest do
  use ExUnit.Case, async: true

  import Phoenix.Component
  import Phoenix.LiveViewTest
  import HuddlzWeb.CoreComponents

  describe "page_tab/1" do
    test "renders active and inactive tab states" do
      assigns = %{}

      active_html =
        rendered_to_string(~H"""
        <.page_tab href="/me" active>Active</.page_tab>
        """)

      inactive_html =
        rendered_to_string(~H"""
        <.page_tab href="/me">Inactive</.page_tab>
        """)

      assert active_html =~ "rounded-hz-control"
      assert active_html =~ "border-primary"
      assert active_html =~ "bg-primary"
      assert active_html =~ "Active"

      assert inactive_html =~ "border-base-300"
      assert inactive_html =~ "bg-base-100"
      assert inactive_html =~ "Inactive"
    end
  end

  describe "surface_panel/1" do
    test "renders a solid div panel by default" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.surface_panel class="p-6">Panel</.surface_panel>
        """)

      assert html =~ ~s(<div)
      assert html =~ "rounded-hz-surface"
      assert html =~ "border-base-300"
      refute html =~ "border-dashed"
      assert html =~ "Panel"
    end

    test "renders alternate tags and dashed panels" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.surface_panel tag="li" variant="dashed" class="p-5">Row</.surface_panel>
        """)

      assert html =~ ~s(<li)
      assert html =~ "rounded-hz-surface"
      assert html =~ "border-dashed"
      assert html =~ "p-5"
      assert html =~ "Row"
    end
  end
end
