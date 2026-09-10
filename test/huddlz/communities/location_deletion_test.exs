defmodule Huddlz.Communities.LocationDeletionTest do
  use Huddlz.DataCase, async: true

  alias Huddlz.Communities

  for {label, state, private?} <- [{"private huddl", :published, true}, {"draft", :draft, false}] do
    test "deletion preserves the location and its link to an upcoming #{label}" do
      owner = generate(user())
      group = generate(group(actor: owner))
      location = generate(group_location(group_id: group.id, actor: owner))

      huddl =
        generate(
          huddl_at_location(
            group_id: group.id,
            creator_id: owner.id,
            group_location_id: location.id,
            lifecycle_state: unquote(state),
            is_private: unquote(private?)
          )
        )

      assert {:error, error} = Communities.delete_group_location(location, actor: owner)
      assert Exception.message(error) =~ "used by 1 current or upcoming huddl"
      assert Communities.get_group_location!(location.id, actor: owner).id == location.id

      assert Communities.get_huddl!(huddl.id, actor: owner).group_location_id == location.id
    end
  end
end
