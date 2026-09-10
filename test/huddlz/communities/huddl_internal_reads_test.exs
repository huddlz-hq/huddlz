defmodule Huddlz.Communities.HuddlInternalReadsTest do
  use Huddlz.DataCase, async: true

  alias Huddlz.Communities.Huddl

  test "internal lookups do not expose private huddlz to ordinary callers" do
    owner = generate(user())
    outsider = generate(user())
    group = generate(group(actor: owner))
    huddl = generate(huddl(group_id: group.id, creator_id: owner.id, is_private: true))

    for action <- [:get_for_recurrence, :get_for_mutation, :get_for_lifecycle_transition] do
      for actor <- [nil, outsider] do
        query = Ash.Query.for_read(Huddl, action, %{id: huddl.id}, actor: actor)
        assert {:ok, []} = Ash.read(query)
      end

      query = Ash.Query.for_read(Huddl, action, %{id: huddl.id}, authorize?: false)
      assert {:ok, [record]} = Ash.read(query)
      assert record.id == huddl.id
    end
  end
end
