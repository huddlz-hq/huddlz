defmodule BrowserDiscoverNavigationSteps do
  use Cucumber.StepDefinition

  import Huddlz.Generator
  import Huddlz.Test.BrowserHelpers
  import PhoenixTest
  import PhoenixTest.Playwright, only: [evaluate: 3]

  step "a public huddl titled {string} is upcoming", %{args: [title]} = context do
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

    Map.put(context, :huddl, huddl)
  end

  step "I have opened my agenda in a browser", context do
    member = generate(user(role: :user))

    conn =
      context.conn
      |> sign_in(member)
      |> visit("/agenda")
      |> assert_has(".phx-connected")
      |> assert_has("h1", text: "Agenda")

    Map.merge(context, %{conn: conn, member: member})
  end

  step "I follow Discover in the sidebar", context do
    evaluate(context.conn, "window.__huddlzPage = 'kept'", fn _ -> :ok end)

    conn = click_link(context.conn, ".sb-nav a", "Discover")

    Map.put(context, :conn, conn)
  end

  step "the discover results arrive without a page load", context do
    conn =
      context.conn
      |> assert_has("h1", text: "Browse huddlz")
      |> assert_has("h3.card-title", text: context.huddl.title)
      |> refute_has(".grid-skeleton")
      |> assert_browser("window.__huddlzPage === 'kept'")

    Map.put(context, :conn, conn)
  end
end
