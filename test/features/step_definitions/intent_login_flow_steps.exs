defmodule IntentLoginFlowSteps do
  @moduledoc """
  Steps for POC variant E: the question asked after signing in, when the app
  has no better idea of what the person came for.
  """
  use Cucumber.StepDefinition

  import PhoenixTest
  import Huddlz.Generator

  @question "What brings you to huddlz today?"

  step "a public group {string} has a huddl {string}",
       %{args: [group_name, huddl_title]} = context do
    owner = generate(user(role: :user))

    group =
      generate(group(name: group_name, owner_id: owner.id, is_public: true, actor: owner))

    huddl =
      generate(
        huddl(
          title: huddl_title,
          group_id: group.id,
          creator_id: owner.id,
          actor: owner,
          is_private: false
        )
      )

    Map.merge(context, %{group: group, huddl: huddl})
  end

  step "the user navigates to the sign in page for that huddl", context do
    %{group: group, huddl: huddl} = context
    session = context[:session] || context[:conn] || Phoenix.ConnTest.build_conn()

    return_to = "/groups/#{group.slug}/huddlz/#{huddl.id}"
    session = visit(session, "/sign-in?" <> URI.encode_query(return_to: return_to))

    Map.merge(context, %{session: session, conn: session})
  end

  step "the user is on that huddl page", context do
    %{group: group, huddl: huddl} = context
    session = context[:session] || context[:conn] || Phoenix.ConnTest.build_conn()
    session = visit(session, "/groups/#{group.slug}/huddlz/#{huddl.id}")
    Map.merge(context, %{session: session, conn: session})
  end

  # The header's sign-in link as variant A makes it render: a destination
  # carried as `return_to`. On this branch the header link is still bare, so
  # the step builds the address A produces rather than reaching into another
  # variant's change. What is under test here is E's side of the contract —
  # that a carried destination wins and the question never appears.
  step "the user signs in from a header link carrying that huddl as the destination",
       context do
    %{group: group, huddl: huddl} = context
    session = context[:session] || context[:conn]

    return_to = "/groups/#{group.slug}/huddlz/#{huddl.id}"
    session = visit(session, "/sign-in?" <> URI.encode_query(return_to: return_to))

    Map.merge(context, %{session: session, conn: session})
  end

  step "the user is asked what they came for", context do
    session = context[:session] || context[:conn]

    session
    |> assert_path("/welcome")
    |> assert_has("h1", text: @question)

    context
  end

  step "the user is not asked what they came for", context do
    session = context[:session] || context[:conn]
    refute_has(session, "h1", text: @question)
    context
  end

  step "the user chooses {string}", %{args: [label]} = context do
    session = context[:session] || context[:conn]
    session = click_button(session, label)
    Map.merge(context, %{session: session, conn: session})
  end

  step "the user skips the question", context do
    session = context[:session] || context[:conn]
    session = click_link(session, "Not sure yet")
    Map.merge(context, %{session: session, conn: session})
  end

  step "the user lands on discover", context do
    session = context[:session] || context[:conn]

    session
    |> assert_path("/discover")
    |> assert_has("h1", text: "Browse huddlz")

    context
  end

  step "the user lands on the agenda page", context do
    session = context[:session] || context[:conn]

    session
    |> assert_path("/agenda")
    |> assert_has("h1", text: "Agenda", exact: true)

    context
  end

  step "the user lands on the huddl {string}", %{args: [title]} = context do
    session = context[:session] || context[:conn]
    assert_has(session, "h1", text: title)
    context
  end

  step "the user signs out", context do
    session = context[:session] || context[:conn]
    session = click_link(session, "Sign out")
    Map.merge(context, %{session: session, conn: session})
  end
end
