defmodule FirstRunEmptyStatesSteps do
  use Cucumber.StepDefinition

  import ExUnit.Assertions
  import Huddlz.Generator
  import PhoenixTest

  step "I attended a huddl last month", context do
    host = generate(user(role: :user))
    group = generate(group(owner_id: host.id, actor: host))
    huddl = generate(past_huddl(group_id: group.id, creator_id: host.id))

    huddl
    |> Ash.Changeset.for_update(:rsvp, %{}, actor: context.current_user)
    |> Ash.update!(authorize?: false)

    context
  end

  step "I own a group with no huddlz", context do
    group =
      generate(
        group(
          name: "Sunrise Runners",
          is_public: true,
          owner_id: context.current_user.id,
          actor: context.current_user
        )
      )

    Map.put(context, :group, group)
  end

  step "I visit my group's page", context do
    session = visit(context.conn, "/groups/#{context.group.slug}")
    Map.merge(context, %{session: session, conn: session})
  end

  step "I am offered {string} and {string}", %{args: [first, second]} = context do
    session = context[:session] || context[:conn]

    session
    |> assert_has(".empty-state a", text: first)
    |> assert_has(".empty-state a", text: second)

    assert true
    context
  end
end
