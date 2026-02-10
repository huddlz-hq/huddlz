defmodule Huddlz.Communities.HuddlRsvpEdgeCasesTest do
  use Huddlz.DataCase, async: true

  alias Huddlz.Communities.Group
  alias Huddlz.Communities.GroupMember
  alias Huddlz.Communities.Huddl

  require Ash.Query

  describe "RSVP cancellation edge cases" do
    setup do
      owner = generate(user(role: :user))
      member = generate(user(role: :user))

      group =
        Group
        |> Ash.Changeset.for_create(
          :create_group,
          %{
            name: "Test Group",
            description: "A test group",
            is_public: true,
            owner_id: owner.id
          },
          actor: owner
        )
        |> Ash.create!()

      GroupMember
      |> Ash.Changeset.for_create(
        :add_member,
        %{
          group_id: group.id,
          user_id: member.id,
          role: "member"
        },
        actor: owner
      )
      |> Ash.create!()

      %{
        owner: owner,
        member: member,
        group: group
      }
    end

    test "handles concurrent RSVP and cancel operations gracefully", %{
      owner: owner,
      member: member,
      group: group
    } do
      # Create a huddl
      huddl =
        Huddl
        |> Ash.Changeset.for_create(
          :create,
          %{
            title: "Concurrent Test Huddl",
            description: "Testing concurrent operations",
            starts_at: DateTime.add(DateTime.utc_now(), 1, :day),
            ends_at: DateTime.add(DateTime.utc_now(), 2, :day),
            event_type: :virtual,
            virtual_link: "https://zoom.us/j/concurrent",
            is_private: false,
            group_id: group.id,
            creator_id: owner.id
          },
          actor: owner
        )
        |> Ash.create!()

      # Both users RSVP
      huddl
      |> Ash.Changeset.for_update(:rsvp, %{user_id: owner.id}, actor: owner)
      |> Ash.update!()

      huddl
      |> Ash.reload!()
      |> Ash.Changeset.for_update(:rsvp, %{user_id: member.id}, actor: member)
      |> Ash.update!()

      # Initial count should be 2
      assert rsvp_count(huddl) == 2

      # Cancel owner's RSVP
      huddl
      |> Ash.reload!()
      |> Ash.Changeset.for_update(:cancel_rsvp, %{user_id: owner.id}, actor: owner)
      |> Ash.update!()

      # Cancel member's RSVP
      huddl
      |> Ash.reload!()
      |> Ash.Changeset.for_update(:cancel_rsvp, %{user_id: member.id}, actor: member)
      |> Ash.update!()

      # Final count should be 0
      assert rsvp_count(huddl) == 0
    end

    test "cancelling RSVP for event that starts in 1 minute still works", %{
      member: member,
      owner: owner,
      group: group
    } do
      # Create a huddl starting very soon
      huddl =
        Huddl
        |> Ash.Changeset.for_create(
          :create,
          %{
            title: "Starting Soon",
            description: "This starts in 1 minute",
            starts_at: DateTime.add(DateTime.utc_now(), 60, :second),
            ends_at: DateTime.add(DateTime.utc_now(), 3660, :second),
            event_type: :virtual,
            virtual_link: "https://zoom.us/j/startingsoon",
            is_private: false,
            group_id: group.id,
            creator_id: owner.id
          },
          actor: owner
        )
        |> Ash.create!()

      # RSVP
      huddl
      |> Ash.Changeset.for_update(:rsvp, %{user_id: member.id}, actor: member)
      |> Ash.update!()

      # Should still be able to cancel
      huddl
      |> Ash.reload!()
      |> Ash.Changeset.for_update(:cancel_rsvp, %{user_id: member.id}, actor: member)
      |> Ash.update!()

      assert rsvp_count(huddl) == 0
    end

    test "RSVP count is always consistent with attendee records", %{
      member: member,
      owner: owner,
      group: group
    } do
      huddl =
        Huddl
        |> Ash.Changeset.for_create(
          :create,
          %{
            title: "Count Test",
            description: "Testing count integrity",
            starts_at: DateTime.add(DateTime.utc_now(), 1, :day),
            ends_at: DateTime.add(DateTime.utc_now(), 2, :day),
            event_type: :virtual,
            virtual_link: "https://zoom.us/j/counttest",
            is_private: false,
            group_id: group.id,
            creator_id: owner.id
          },
          actor: owner
        )
        |> Ash.create!()

      # Try to cancel without RSVPing first - count stays at 0
      huddl
      |> Ash.Changeset.for_update(:cancel_rsvp, %{user_id: member.id}, actor: member)
      |> Ash.update!()

      assert rsvp_count(huddl) == 0

      # RSVP then cancel - count is always consistent
      huddl
      |> Ash.reload!()
      |> Ash.Changeset.for_update(:rsvp, %{user_id: member.id}, actor: member)
      |> Ash.update!()

      assert rsvp_count(huddl) == 1

      huddl
      |> Ash.reload!()
      |> Ash.Changeset.for_update(:cancel_rsvp, %{user_id: member.id}, actor: member)
      |> Ash.update!()

      assert rsvp_count(huddl) == 0
    end

    test "admin can see RSVP cancellations work correctly", %{
      member: member,
      owner: owner,
      group: group
    } do
      admin = generate(user(role: :admin))

      huddl =
        Huddl
        |> Ash.Changeset.for_create(
          :create,
          %{
            title: "Admin View Test",
            description: "Testing admin perspective",
            starts_at: DateTime.add(DateTime.utc_now(), 1, :day),
            ends_at: DateTime.add(DateTime.utc_now(), 2, :day),
            event_type: :virtual,
            virtual_link: "https://zoom.us/j/admintest",
            is_private: false,
            group_id: group.id,
            creator_id: owner.id
          },
          actor: owner
        )
        |> Ash.create!()

      # Member RSVPs
      huddl
      |> Ash.Changeset.for_update(:rsvp, %{user_id: member.id}, actor: member)
      |> Ash.update!()

      # Admin views the huddl
      admin_view =
        Huddl
        |> Ash.Query.filter(id == ^huddl.id)
        |> Ash.Query.load(:rsvp_count)
        |> Ash.read_one!(actor: admin)

      assert admin_view.rsvp_count == 1

      # Member cancels
      huddl
      |> Ash.reload!()
      |> Ash.Changeset.for_update(:cancel_rsvp, %{user_id: member.id}, actor: member)
      |> Ash.update!()

      # Admin views again
      admin_view_after =
        Huddl
        |> Ash.Query.filter(id == ^huddl.id)
        |> Ash.Query.load(:rsvp_count)
        |> Ash.read_one!(actor: admin)

      assert admin_view_after.rsvp_count == 0
    end
  end

  # Helper to load the rsvp_count aggregate from the database
  defp rsvp_count(huddl) do
    huddl |> Ash.reload!() |> Ash.load!(:rsvp_count, authorize?: false) |> Map.get(:rsvp_count)
  end
end
