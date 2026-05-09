defmodule SharedHuddlSteps do
  use Cucumber.StepDefinition
  import Huddlz.Generator
  import ExUnit.Assertions

  alias Huddlz.Communities.Huddl

  require Ash.Query

  step "the huddl {string} should have coordinates {float}, {float}",
       %{args: [title, lat, lng]} = context do
    huddl =
      Huddl
      |> Ash.Query.filter(title == ^title)
      |> Ash.read_one!(authorize?: false)

    assert huddl, "Expected a huddl titled #{inspect(title)} to exist"
    assert huddl.latitude == lat, "expected latitude #{lat}, got #{inspect(huddl.latitude)}"
    assert huddl.longitude == lng, "expected longitude #{lng}, got #{inspect(huddl.longitude)}"

    context
  end

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
