defmodule HuddlGroupLinkSteps do
  use Cucumber.StepDefinition

  import Huddlz.Generator
  import PhoenixTest

  alias Huddlz.Communities.GroupMember

  step "a public group {string} in {string} with {int} other members",
       %{args: [name, location, extra_members]} = context do
    owner = generate(user(role: :user))

    group =
      generate(
        group(name: name, location: location, is_public: true, owner_id: owner.id, actor: owner)
      )

    for _ <- 1..extra_members do
      member = generate(user(role: :user))

      GroupMember
      |> Ash.Changeset.for_create(
        :add_member,
        %{group_id: group.id, user_id: member.id, role: "member"},
        actor: owner
      )
      |> Ash.create!()
    end

    Map.merge(context, %{group: group, owner: owner})
  end

  step "an upcoming huddl {string} hosted by that group", %{args: [title]} = context do
    huddl =
      generate(
        huddl(
          group_id: context.group.id,
          creator_id: context.owner.id,
          is_private: false,
          title: title,
          actor: context.owner
        )
      )

    Map.put(context, :huddl, huddl)
  end

  step "I read the huddl page for {string}", %{args: [title]} = context do
    session =
      context.conn
      |> visit("/groups/#{context.group.slug}/huddlz/#{context.huddl.id}")
      |> assert_has("h1", text: title)

    Map.merge(context, %{conn: session, session: session})
  end

  step "the huddl says it is hosted by {string} with {string}",
       %{args: [group_name, members]} = context do
    context.conn
    |> assert_has("#huddl-hero-group", text: group_name)
    |> assert_has("#huddl-group-link", text: group_name)
    |> assert_has("#huddl-group-link", text: members)

    context
  end

  step "I follow the hosting group link", context do
    session = click_link(context.conn, "#huddl-group-link", to_string(context.group.name))

    Map.merge(context, %{conn: session, session: session})
  end

  step "I am on the group page for {string}", %{args: [group_name]} = context do
    context.conn
    |> assert_path("/groups/#{context.group.slug}")
    |> assert_has("h1", text: group_name)

    context
  end
end
