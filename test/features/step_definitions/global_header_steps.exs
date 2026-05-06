defmodule GlobalHeaderSteps do
  use Cucumber.StepDefinition
  import PhoenixTest

  step "the header should show the huddlz brand", context do
    session = context[:session] || context[:conn]
    assert_has(session, "header a[href='/']", text: "huddlz")
    context
  end

  step "the header should expose a global search form posting q to /discover", context do
    session = context[:session] || context[:conn]

    session
    |> assert_has("header form[role='search'][method='get'][action='/discover']")
    |> assert_has("header input[type='search'][name='q'][placeholder='Search huddlz']")

    context
  end

  step "the header should expose an Organize link to /groups/new", context do
    session = context[:session] || context[:conn]
    assert_has(session, "header a[href='/groups/new']", text: "Organize")
    context
  end

  step "the header should not expose a Groups link", context do
    session = context[:session] || context[:conn]
    refute_has(session, "header a[href='/groups']", text: "Groups")
    context
  end

  step "the account menu should expose the member, organizer, and account links", context do
    session = context[:session] || context[:conn]

    session
    |> assert_has("#user-menu a[href='/me?tab=huddlz']", text: "My huddlz")
    |> assert_has("#user-menu a[href='/me?tab=groups']", text: "My groups")
    |> assert_has("#user-menu a[href='/organize']", text: "Organizer workspace")
    |> assert_has("#user-menu a[href='/profile']", text: "Profile & preferences")
    |> assert_has("#user-menu a[href='/discover']", text: "Discover huddlz")
    |> assert_has("#user-menu a[href='/sign-out']", text: "Sign out")

    context
  end
end
