defmodule DiscoverCombinedSteps do
  use Cucumber.StepDefinition

  import Huddlz.Generator

  alias Huddlz.Accounts.User
  alias Huddlz.Communities.Group

  require Ash.Query

  step "a group named {string} is owned by {string}",
       %{args: [group_name, owner_email]} = context do
    owner = lookup_user(owner_email)

    generate(
      group(
        name: group_name,
        owner_id: owner.id,
        is_public: true,
        actor: owner
      )
    )

    context
  end

  step "the group {string} has an upcoming huddl titled {string}",
       %{args: [group_name, huddl_title]} = context do
    group = lookup_group(group_name)
    owner = Ash.get!(User, group.owner_id, authorize?: false)

    generate(
      huddl(
        group_id: group.id,
        creator_id: owner.id,
        is_private: false,
        title: huddl_title,
        actor: owner
      )
    )

    context
  end

  defp lookup_user(email) do
    User
    |> Ash.Query.filter(email: email)
    |> Ash.read_one!(authorize?: false)
  end

  defp lookup_group(name) do
    Group
    |> Ash.Query.filter(name: name)
    |> Ash.read_one!(authorize?: false)
  end
end
