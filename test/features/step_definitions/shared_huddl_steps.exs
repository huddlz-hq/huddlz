defmodule SharedHuddlSteps do
  use Cucumber.StepDefinition
  import Huddlz.Generator

  step "the following huddlz exist:", context do
    huddlz =
      context.datatable.maps
      |> Enum.map(fn huddl_data ->
        host =
          Enum.find(context.users, fn u ->
            to_string(u.display_name) == huddl_data["creator_name"]
          end)

        group =
          generate(
            group(owner_id: host.id, name: huddl_data["group_name"], is_public: true, actor: host)
          )

        generate(
          huddl(
            group_id: group.id,
            creator_id: host.id,
            is_private: false,
            title: huddl_data["name"],
            actor: host
          )
        )
      end)

    Map.put(context, :huddlz, huddlz)
  end
end
