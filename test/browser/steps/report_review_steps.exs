defmodule BrowserReportReviewSteps do
  use Cucumber.StepDefinition
  use Fluffy.Assert

  import Fluffy, except: [step: 2, step: 3]
  import Fluffy.Locator
  import Huddlz.Generator
  import Huddlz.Test.BrowserHelpers

  alias Huddlz.Accounts

  step "I am reviewing a reported account in a browser", %{session: session} do
    owner = generate(user(display_name: "Sam Rivera"))
    reporter = generate(user(display_name: "Ada Park"))
    admin = generate(user(role: :admin, display_name: "Alex Admin"))
    generate_group_with_members(owner: owner, members: [%{user: reporter, role: :member}])

    Accounts.report_account!(
      %{reported_user_id: owner.id, reason: :spam, details: "Repeated advertisements"},
      actor: reporter
    )

    Accounts.suspend_user!(owner, "Repeated advertisements", actor: admin)

    session |> sign_in(admin) |> visit("/admin/reports")

    %{reported: owner}
  end

  step "the report review controls stay together", %{session: session} = context do
    check_controls(session)
    screenshot(session, "reports-#{size(context)}.png")
    :ok
  end

  step "I handle and reopen the report", %{session: session} do
    session
    |> click(review())
    |> click(by_role(review_card(), :button, name: "Mark handled"))
    |> click(by_role(:link, name: "Handled"))
    |> click(review())
    |> click(by_role(:button, name: "Reopen"))

    :ok
  end

  step "the reopened report is ready for review", %{session: session} do
    session
    |> assert(visible(review_card() |> filter(has_text: "Repeated advertisements")))
    |> assert(visible(by_role(review_card(), :button, name: "Mark handled")))
    |> assert(count(by_role(:button, name: "Suspend account"), 0))
    |> assert(page_url(&(not Map.has_key?(URI.decode_query(&1.query || ""), "account_id"))))

    :ok
  end

  step "I review the suspended account in Users", %{session: session} do
    session
    |> visit("/admin/users?scope=suspended")
    |> click(review())
    |> assert(visible(by_role(review_card(), :link, name: "1 open report")))

    :ok
  end

  step "the account review controls stay together", %{session: session} = context do
    check_controls(session)
    screenshot(session, "users-review-#{size(context)}.png")
    :ok
  end

  defp review, do: by_role(:button, name: "Review", exact: true)
  defp review_card, do: by_css(".review-card")

  defp screenshot(session, name),
    do:
      Fluffy.Playwright.screenshot(session,
        path: "_build/browser/screenshots/#{name}",
        full_page: true
      )

  defp size(context), do: if(Map.get(context, :mobile), do: "mobile", else: "desktop")

  defp check_controls(session) do
    assert_browser(session, """
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
