defmodule ShareLinksSteps do
  use Cucumber.StepDefinition

  import ExUnit.Assertions
  import Huddlz.Generator
  import PhoenixTest

  step "a public huddl {string}", %{args: [title]} = context do
    owner = generate(user(role: :user))
    group = generate(group(is_public: true, owner_id: owner.id, actor: owner))

    huddl =
      generate(
        huddl(
          group_id: group.id,
          creator_id: owner.id,
          is_private: false,
          title: title,
          actor: owner
        )
      )

    Map.merge(context, %{group: group, huddl: huddl})
  end

  step "I open the huddl page", context do
    session = context[:session] || context[:conn] || Phoenix.ConnTest.build_conn()
    session = visit(session, "/groups/#{context.group.slug}/huddlz/#{context.huddl.id}")
    Map.merge(context, %{session: session, conn: session})
  end

  step "I can copy the huddl's link from the Share section", context do
    assert_copies(context.session, huddl_url(context.group, context.huddl))
    context
  end

  defp assert_copies(session, url) do
    assert_has(session, "#share-actions button[data-value='#{url}']", text: "Copy link")
  end

  defp huddl_url(group, huddl) do
    HuddlzWeb.Endpoint.url() <> "/groups/#{group.slug}/huddlz/#{huddl.id}"
  end
end
