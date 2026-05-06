defmodule GlobalFooterSteps do
  use Cucumber.StepDefinition
  import PhoenixTest

  step "the footer should show the huddlz brand block", context do
    session = context[:session] || context[:conn]

    session
    |> assert_has("footer", text: "huddlz")
    |> assert_has("footer", text: "Real-life communities, easier to discover and organize.")

    context
  end

  step "the footer should expose the Product, Help, Legal, and Open columns", context do
    session = context[:session] || context[:conn]

    session
    |> assert_has("footer nav[aria-label='Product'] h2", text: "Product")
    |> assert_has("footer nav[aria-label='Help'] h2", text: "Help")
    |> assert_has("footer nav[aria-label='Legal'] h2", text: "Legal")
    |> assert_has("footer nav[aria-label='Open'] h2", text: "Open")

    context
  end

  step "the footer should link to GitHub and the API docs", context do
    session = context[:session] || context[:conn]

    session
    |> assert_has("footer a[href='https://github.com/huddlz-hq/huddlz']", text: "GitHub")
    |> assert_has("footer a[href='/api/json/swaggerui']", text: "API docs")

    context
  end

  step "the footer should show the closing line {string}", %{args: [line]} = context do
    session = context[:session] || context[:conn]
    assert_has(session, "footer", text: line)
    context
  end
end
