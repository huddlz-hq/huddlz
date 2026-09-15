defmodule BrowserReportReviewSteps do
  use Cucumber.StepDefinition

  import Huddlz.Generator
  import Huddlz.Test.BrowserHelpers
  import PhoenixTest

  alias Huddlz.Accounts
  alias PhoenixTest.Playwright

  step "I am reviewing a reported account in a browser", context do
    owner = generate(user(display_name: "Sam Rivera"))
    reporter = generate(user(display_name: "Ada Park"))
    admin = generate(user(role: :admin, display_name: "Alex Admin"))
    generate_group_with_members(owner: owner, members: [%{user: reporter, role: :member}])

    Accounts.report_account!(
      %{reported_user_id: owner.id, reason: :spam, details: "Repeated advertisements"},
      actor: reporter
    )

    Accounts.suspend_user!(owner, "Repeated advertisements", actor: admin)

    conn =
      context.conn |> sign_in(admin) |> visit("/admin/reports") |> assert_has(".phx-connected")

    Map.merge(context, %{conn: conn, reported: owner})
  end

  step "the report review controls stay together", context do
    check_controls(context.conn)
    Playwright.screenshot(context.conn, "reports-#{size(context)}.png")
    context
  end

  step "I handle and reopen the report", context do
    conn =
      context.conn
      |> click_button("Review")
      |> click_button(".review-card button", "Mark handled")
      |> click_link("Handled")
      |> click_button("Review")
      |> click_button("Reopen")

    Map.put(context, :conn, conn)
  end

  step "the reopened report is ready for review", context do
    conn =
      context.conn
      |> assert_has(".review-card", text: "Repeated advertisements")
      |> assert_has(".review-card button", text: "Mark handled")

    Map.put(context, :conn, conn)
  end

  step "I review the suspended account in Users", context do
    conn =
      context.conn
      |> visit("/admin/users?scope=suspended")
      |> assert_has(".phx-connected")
      |> click_button("Review")
      |> assert_has(".review-card a", text: "1 open report")

    Map.put(context, :conn, conn)
  end

  step "the account review controls stay together", context do
    check_controls(context.conn)
    Playwright.screenshot(context.conn, "users-review-#{size(context)}.png")
    context
  end

  defp size(context), do: if(Map.get(context, :mobile), do: "mobile", else: "desktop")

  defp check_controls(conn) do
    assert_browser(conn, """
    (() => {
      const row = document.querySelector('.member-row');
      const review = row.querySelector('button[phx-click="review"]').getBoundingClientRect();
      const menu = row.querySelector('.member-menu-trigger').getBoundingClientRect();
      return Math.abs((review.top + review.bottom) / 2 - (menu.top + menu.bottom) / 2) < 2 &&
        review.right <= menu.left &&
        document.documentElement.scrollWidth <= innerWidth;
    })()
    """)
  end
end
