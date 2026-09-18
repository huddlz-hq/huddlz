defmodule Huddlz.Communities.DropInGroupsTest do
  @moduledoc """
  Which groups count as ones a person has dropped in on: public groups they
  have not joined, where they hold an RSVP or waitlist spot on a published
  huddl or held an RSVP at a completed one, unless they said "Not now", left,
  or were removed (ADR-0011).
  """
  use Huddlz.DataCase, async: true

  alias Huddlz.Communities
  alias Huddlz.Communities.HuddlAttendee

  setup do
    owner = generate(user(role: :user))
    person = generate(user(role: :user))
    group = generate(group(owner_id: owner.id, actor: owner, is_public: true))

    %{owner: owner, person: person, group: group}
  end

  defp upcoming(group, owner, opts \\ []) do
    generate(huddl([group_id: group.id, creator_id: owner.id, is_private: false] ++ opts))
  end

  defp finished(group, owner, state) do
    generate(
      past_huddl(
        group_id: group.id,
        creator_id: owner.id,
        is_private: false,
        lifecycle_state: state
      )
    )
  end

  defp hold_rsvp(person, huddl) do
    HuddlAttendee
    |> Ash.Changeset.for_create(:rsvp, %{huddl_id: huddl.id, user_id: person.id})
    |> Ash.create!(authorize?: false)
  end

  defp hold_waitlist_spot(person, huddl) do
    HuddlAttendee
    |> Ash.Changeset.for_create(:join_waitlist, %{huddl_id: huddl.id, user_id: person.id})
    |> Ash.create!(authorize?: false)
  end

  defp dropped_in(person) do
    Communities.groups_for_actor!(:dropped_in, actor: person) |> page_ids()
  end

  defp page_ids(%{results: results}), do: Enum.map(results, & &1.id)
  defp page_ids(results) when is_list(results), do: Enum.map(results, & &1.id)

  test "an RSVP to an upcoming huddl counts", %{owner: owner, person: person, group: group} do
    Communities.rsvp_huddl!(upcoming(group, owner), actor: person)
    assert dropped_in(person) == [group.id]
  end

  test "a waitlist spot on an upcoming huddl counts", ctx do
    hold_waitlist_spot(ctx.person, upcoming(ctx.group, ctx.owner))
    assert dropped_in(ctx.person) == [ctx.group.id]
  end

  test "an RSVP held when the huddl completed counts", ctx do
    hold_rsvp(ctx.person, finished(ctx.group, ctx.owner, :completed))
    assert dropped_in(ctx.person) == [ctx.group.id]
  end

  test "a waitlist spot at a completed huddl does not count", ctx do
    hold_waitlist_spot(ctx.person, finished(ctx.group, ctx.owner, :completed))
    assert dropped_in(ctx.person) == []
  end

  # A huddl that is over stays published until the completion job records it,
  # so the end time decides, not the lifecycle state.
  defp end_now(huddl) do
    ended_at = DateTime.add(DateTime.utc_now(), -60, :second)

    Ash.Seed.update!(huddl, %{
      starts_at: DateTime.add(ended_at, -1, :hour),
      ends_at: ended_at
    })
  end

  test "an RSVP still counts once the huddl has ended but is not yet completed", ctx do
    huddl = upcoming(ctx.group, ctx.owner)
    Communities.rsvp_huddl!(huddl, actor: ctx.person)
    end_now(huddl)

    assert dropped_in(ctx.person) == [ctx.group.id]
    assert [_spot] = Communities.list_drop_in_spots!([ctx.group.id], actor: ctx.person)
  end

  test "a waitlist spot stops counting the moment the huddl ends", ctx do
    huddl = upcoming(ctx.group, ctx.owner)
    hold_waitlist_spot(ctx.person, huddl)
    end_now(huddl)

    assert dropped_in(ctx.person) == []
    assert [] == Communities.list_drop_in_spots!([ctx.group.id], actor: ctx.person)
  end

  test "a cancelled huddl does not count", ctx do
    hold_rsvp(ctx.person, finished(ctx.group, ctx.owner, :cancelled))
    assert dropped_in(ctx.person) == []
  end

  test "someone who never RSVPd has not dropped in", ctx do
    upcoming(ctx.group, ctx.owner)
    assert dropped_in(ctx.person) == []
  end

  test "members and the owner are not drop-ins", %{owner: owner, person: person, group: group} do
    huddl = upcoming(group, owner)
    Communities.join_group!(group.id, actor: person)
    Communities.rsvp_huddl!(huddl, actor: person)

    assert dropped_in(person) == []
    assert dropped_in(owner) == []
  end

  test "dropped-in groups are never part of the person's own groups", ctx do
    Communities.rsvp_huddl!(upcoming(ctx.group, ctx.owner), actor: ctx.person)
    assert Communities.groups_for_actor!(:all, actor: ctx.person) |> page_ids() == []
  end

  test "Not now removes the group for good", %{owner: owner, person: person, group: group} do
    Communities.rsvp_huddl!(upcoming(group, owner), actor: person)
    Communities.dismiss_join_suggestion!(group.id, actor: person)
    Communities.rsvp_huddl!(upcoming(group, owner), actor: person)

    assert dropped_in(person) == []
  end

  test "Not now twice is harmless", %{owner: owner, person: person, group: group} do
    Communities.rsvp_huddl!(upcoming(group, owner), actor: person)
    first = Communities.dismiss_join_suggestion!(group.id, actor: person)
    second = Communities.dismiss_join_suggestion!(group.id, actor: person)

    assert first.id == second.id
  end

  test "one person's Not now does not affect another", %{
    owner: owner,
    person: person,
    group: group
  } do
    other = generate(user(role: :user))
    huddl = upcoming(group, owner)
    Communities.rsvp_huddl!(huddl, actor: person)
    Communities.rsvp_huddl!(huddl, actor: other)
    Communities.dismiss_join_suggestion!(group.id, actor: person)

    assert dropped_in(other) == [group.id]
  end

  test "leaving the group ends it", %{owner: owner, person: person, group: group} do
    membership = Communities.join_group!(group.id, actor: person)
    :ok = Communities.leave_group!(membership, actor: person)
    Communities.rsvp_huddl!(upcoming(group, owner), actor: person)

    assert dropped_in(person) == []
  end

  test "being removed from the group ends it", %{owner: owner, person: person, group: group} do
    membership = Communities.join_group!(group.id, actor: person)
    :ok = Communities.remove_member!(membership, group.id, person.id, actor: owner)
    Communities.rsvp_huddl!(upcoming(group, owner), actor: person)

    assert dropped_in(person) == []
  end

  test "an archived group is not suggested", %{owner: owner, person: person, group: group} do
    huddl = upcoming(group, owner)
    Communities.rsvp_huddl!(huddl, actor: person)
    Communities.cancel_huddl!(huddl, nil, actor: owner)
    Communities.archive_group!(group, actor: owner)

    assert dropped_in(person) == []
  end

  test "a group that turned private is not suggested", %{
    owner: owner,
    person: person,
    group: group
  } do
    Communities.rsvp_huddl!(upcoming(group, owner), actor: person)

    group
    |> Ash.Changeset.for_update(:update_details, %{is_public: false}, actor: owner)
    |> Ash.update!()

    assert dropped_in(person) == []
  end

  test "the reminder row is private to its person", %{owner: owner, person: person, group: group} do
    Communities.dismiss_join_suggestion!(group.id, actor: person)

    assert {:ok, nil} =
             Communities.get_drop_in_reminder(group.id, actor: owner, not_found_error?: false)

    assert {:ok, %{dismissed_at: %DateTime{}}} =
             Communities.get_drop_in_reminder(group.id, actor: person)
  end

  test "closing a reminder is internal only", %{person: person, group: group} do
    assert {:error, %Ash.Error.Forbidden{}} =
             Communities.close_drop_in_reminder(%{group_id: group.id, user_id: person.id},
               actor: person
             )
  end
end
