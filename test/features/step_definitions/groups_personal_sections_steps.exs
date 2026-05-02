defmodule GroupsPersonalSectionsSteps do
  use Cucumber.StepDefinition

  import Huddlz.Generator

  alias Huddlz.Accounts.User

  require Ash.Query

  step "{string} has joined the group {string}",
       %{args: [email, name]} = context do
    user = lookup_user(email)
    group = lookup_group(name)
    owner = lookup_user_by_id(group.owner_id)

    generate(group_member(group_id: group.id, user_id: user.id, actor: owner))

    context
  end

  step "{string} hosts {int} public groups named {string}",
       %{args: [email, count, prefix]} = context do
    owner = lookup_user(email)

    for i <- 1..count do
      generate(
        group(
          name: "#{prefix} #{i}",
          actor: owner,
          is_public: true,
          location: "Test Location"
        )
      )
    end

    context
  end

  defp lookup_user(email) do
    User
    |> Ash.Query.filter(email: email)
    |> Ash.read_one!(authorize?: false)
  end

  defp lookup_user_by_id(id), do: Ash.get!(User, id, authorize?: false)

  defp lookup_group(name) do
    Huddlz.Communities.Group
    |> Ash.Query.filter(name: name)
    |> Ash.read_one!(authorize?: false)
  end
end
