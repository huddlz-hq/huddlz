defmodule SavedLocationDeletionSteps do
  use Cucumber.StepDefinition

  import Huddlz.Generator

  step "the saved location {string} is used by an upcoming huddl",
       %{args: [location_name]} = context do
    location =
      context
      |> Map.get(:group_locations, [])
      |> Enum.find(&(&1.name == location_name))

    group = Enum.find(context.groups, &(&1.id == location.group_id))
    owner = Enum.find(context.users, &(&1.id == group.owner_id))
    starts_at = DateTime.add(DateTime.utc_now(), 1, :day)

    generate(
      huddl_at_location(
        group_id: location.group_id,
        creator_id: owner.id,
        group_location_id: location.id,
        physical_location: location.address,
        latitude: location.latitude,
        longitude: location.longitude,
        starts_at: starts_at,
        ends_at: DateTime.add(starts_at, 1, :hour)
      )
    )

    context
  end
end
