defmodule Huddlz.Communities.TurnoutTest do
  use Huddlz.DataCase, async: true

  alias Huddlz.Communities

  test "only organizers can dismiss turnout, without losing recorded counts" do
    owner = generate(user())
    member = generate(user())

    {group, _memberships} =
      generate_group_with_members(owner: owner, members: [%{user: member, role: :member}])

    huddl = generate(past_huddl(group_id: group.id, creator_id: owner.id))
    recorded = Communities.record_turnout!(huddl, %{in_room: 7}, actor: owner)

    assert {:error, %Ash.Error.Forbidden{}} = Communities.skip_turnout(recorded, actor: member)
    assert {:ok, skipped} = Communities.skip_turnout(recorded, actor: owner)
    assert %DateTime{} = skipped.turnout_skipped_at

    reloaded = Communities.get_huddl!(huddl.id, actor: owner)
    assert reloaded.turnout_in_room == 7
    assert reloaded.turnout_on_call == nil
    assert reloaded.turnout_recorded_at == recorded.turnout_recorded_at
    assert reloaded.turnout_skipped_at == skipped.turnout_skipped_at
  end
end
