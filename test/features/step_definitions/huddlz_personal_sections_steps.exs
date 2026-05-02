defmodule HuddlzPersonalSectionsSteps do
  use Cucumber.StepDefinition

  import Huddlz.Generator

  alias Huddlz.Accounts.User
  alias Huddlz.Communities.Group

  require Ash.Query

  step "the huddl {string} exists in group {string} hosted by {string}",
       %{args: [title, group_name, host_email]} = context do
    host = lookup_user(host_email)
    group = lookup_group(group_name)

    huddl =
      generate(
        huddl(
          title: title,
          group_id: group.id,
          creator_id: host.id,
          is_private: false,
          actor: host
        )
      )

    huddls = Map.get(context, :huddls, [])
    Map.put(context, :huddls, [huddl | huddls])
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
