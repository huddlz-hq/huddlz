defmodule Huddlz.Communities.Huddl.Changes.ForcePrivateForPrivateGroupsTest do
  use Huddlz.DataCase, async: true

  setup do
    owner = generate(user(role: :user))
    group = generate(group(owner_id: owner.id, is_public: false, actor: owner))

    {:ok, %{owner: owner, group: group}}
  end

  test "create forces is_private for huddlz in private groups", %{owner: owner, group: group} do
    huddl = generate(huddl(group_id: group.id, actor: owner, is_private: false))

    assert huddl.is_private
  end

  test "update cannot flip a private-group huddl public", %{owner: owner, group: group} do
    huddl = generate(huddl(group_id: group.id, actor: owner))

    assert {:ok, updated} =
             huddl
             |> Ash.Changeset.for_update(:update, %{is_private: false}, actor: owner)
             |> Ash.update()

    assert updated.is_private
  end
end
