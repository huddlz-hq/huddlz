defmodule BrowserDiscoverNavigationSteps do
  use Cucumber.StepDefinition
  use Fluffy.Assert

  import Fluffy, except: [step: 3]
  import Fluffy.Locator
  import Huddlz.Generator
  import Huddlz.Test.BrowserHelpers

  step "a public huddl titled {string} is upcoming", %{args: [title]} do
    host = generate(user(role: :user))
    group = generate(group(is_public: true, owner_id: host.id, actor: host))

    huddl =
      generate(
        huddl(
          group_id: group.id,
          creator_id: host.id,
          is_private: false,
          title: title,
          actor: host
        )
      )

    %{huddl: huddl}
  end

  step "I have opened my agenda in a browser", %{session: session} do
    member = generate(user(role: :user))

    session
    |> sign_in(member)
    |> visit("/agenda")
    |> assert(visible(by_role(:heading, level: 1, name: "Agenda")))

    %{member: member}
  end

  step "I follow Discover in the sidebar", %{session: session} do
    Fluffy.Playwright.evaluate(session, "window.__huddlzPage = 'kept'")
    click(session, by_role(by_css(".sb-nav"), :link, name: "Discover"))
    :ok
  end

  step "the discover results arrive without a page load", %{session: session} = context do
    session
    |> assert(visible(by_role(:heading, level: 1, name: "Browse huddlz")))
    |> assert(visible(by_role(:heading, level: 3, name: context.huddl.title)))
    |> assert(count(by_css(".grid-skeleton") |> filter(visible: true), 0))
    |> assert_browser("window.__huddlzPage === 'kept'")

    :ok
  end
end
