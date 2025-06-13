defmodule Huddlz.Communities.HuddlPastActionTest do
  use Huddlz.DataCase

  import Huddlz.Generator

  alias Huddlz.Communities.Huddl

  describe "past action" do
    test "returns huddlz sorted by starts_at descending" do
      # Create a verified user who can see huddlz
      user = generate(user(role: :verified))
      
      # Create a public group
      group = generate(group(owner_id: user.id, is_public: true, actor: user))

      # Create past huddlz with different start times
      old_huddl = generate(
        past_huddl(
          group_id: group.id,
          creator_id: user.id,
          title: "Old Event",
          starts_at: DateTime.add(DateTime.utc_now(), -30, :day),
          ends_at: DateTime.add(DateTime.utc_now(), -29, :day)
        )
      )

      middle_huddl = generate(
        past_huddl(
          group_id: group.id,
          creator_id: user.id,
          title: "Middle Event",
          starts_at: DateTime.add(DateTime.utc_now(), -7, :day),
          ends_at: DateTime.add(DateTime.utc_now(), -6, :day)
        )
      )

      recent_huddl = generate(
        past_huddl(
          group_id: group.id,
          creator_id: user.id,
          title: "Recent Event",
          starts_at: DateTime.add(DateTime.utc_now(), -2, :day),
          ends_at: DateTime.add(DateTime.utc_now(), -1, :day)
        )
      )

      # Query using the past action
      {:ok, past_huddlz} = Huddl
        |> Ash.Query.for_read(:past, %{}, actor: user)
        |> Ash.read()

      # Verify the order - newest first
      assert length(past_huddlz) >= 3
      
      # Find our test huddlz in the results
      huddl_ids = Enum.map(past_huddlz, & &1.id)
      recent_index = Enum.find_index(huddl_ids, &(&1 == recent_huddl.id))
      middle_index = Enum.find_index(huddl_ids, &(&1 == middle_huddl.id))
      old_index = Enum.find_index(huddl_ids, &(&1 == old_huddl.id))

      # Verify they appear in the correct order (newest first)
      assert recent_index < middle_index
      assert middle_index < old_index
    end

    test "only returns events that have ended" do
      user = generate(user(role: :verified))
      group = generate(group(owner_id: user.id, is_public: true, actor: user))

      # Create a huddl that has started but not ended (in progress)
      in_progress_huddl = generate(
        past_huddl(
          group_id: group.id,
          creator_id: user.id,
          title: "In Progress Event",
          starts_at: DateTime.add(DateTime.utc_now(), -1, :hour),
          ends_at: DateTime.add(DateTime.utc_now(), 1, :hour)
        )
      )

      # Create a huddl that has ended
      ended_huddl = generate(
        past_huddl(
          group_id: group.id,
          creator_id: user.id,
          title: "Ended Event",
          starts_at: DateTime.add(DateTime.utc_now(), -3, :hour),
          ends_at: DateTime.add(DateTime.utc_now(), -1, :hour)
        )
      )

      # Create a future huddl
      future_huddl = generate(
        huddl(
          group_id: group.id,
          creator_id: user.id,
          title: "Future Event",
          starts_at: DateTime.add(DateTime.utc_now(), 1, :day),
          ends_at: DateTime.add(DateTime.utc_now(), 2, :day),
          actor: user
        )
      )

      # Query using the past action
      {:ok, past_huddlz} = Huddl
        |> Ash.Query.for_read(:past, %{}, actor: user)
        |> Ash.read()

      past_huddl_ids = Enum.map(past_huddlz, & &1.id)

      # Should only see the ended event
      assert ended_huddl.id in past_huddl_ids
      refute in_progress_huddl.id in past_huddl_ids
      refute future_huddl.id in past_huddl_ids
    end
  end
end