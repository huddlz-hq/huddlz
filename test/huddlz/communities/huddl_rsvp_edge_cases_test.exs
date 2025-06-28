defmodule Huddlz.Communities.HuddlRsvpEdgeCasesTest do
  use Huddlz.DataCase, async: true

  alias Huddlz.Accounts.User
  alias Huddlz.Communities.Group
  alias Huddlz.Communities.GroupMember
  alias Huddlz.Communities.Huddl

  require Ash.Query

  describe "RSVP cancellation edge cases" do
    setup do
      owner = create_verified_user()
      member = create_verified_user()

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
      huddl_after_rsvps = Ash.reload!(huddl)
      assert huddl_after_rsvps.rsvp_count == 2

      # Cancel owner's RSVP
      huddl_after_rsvps
      |> Ash.Changeset.for_update(:cancel_rsvp, %{user_id: owner.id}, actor: owner)
      |> Ash.update!()

      # Cancel member's RSVP
      huddl
      |> Ash.reload!()
      |> Ash.Changeset.for_update(:cancel_rsvp, %{user_id: member.id}, actor: member)
      |> Ash.update!()

      # Final count should be 0
      final_huddl = Ash.reload!(huddl)
      assert final_huddl.rsvp_count == 0
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
      updated_huddl =
        huddl
        |> Ash.reload!()
        |> Ash.Changeset.for_update(:cancel_rsvp, %{user_id: member.id}, actor: member)
        |> Ash.update!()

      assert updated_huddl.rsvp_count == 0
    end

    test "RSVP count never goes negative", %{member: member, owner: owner, group: group} do
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
            creator_id: owner.id,
            rsvp_count: 0
          },
          actor: owner
        )
        |> Ash.create!()

      # Try to cancel without RSVPing first
      result =
        huddl
        |> Ash.Changeset.for_update(:cancel_rsvp, %{user_id: member.id}, actor: member)
        |> Ash.update!()

      assert result.rsvp_count == 0

      # Manually corrupt the count (simulate database inconsistency)
      huddl
      |> Ecto.Changeset.change(%{rsvp_count: 0})
      |> Huddlz.Repo.update!()

      # RSVP to create an attendee record
      huddl
      |> Ash.reload!()
      |> Ash.Changeset.for_update(:rsvp, %{user_id: member.id}, actor: member)
      |> Ash.update!()

      # Reset count to 0 to simulate inconsistency
      huddl
      |> Ecto.Changeset.change(%{rsvp_count: 0})
      |> Huddlz.Repo.update!()

      # Cancel should not make it negative
      result =
        huddl
        |> Ash.reload!()
        |> Ash.Changeset.for_update(:cancel_rsvp, %{user_id: member.id}, actor: member)
        |> Ash.update!()

      assert result.rsvp_count == 0
    end

    test "admin can see RSVP cancellations work correctly", %{
      member: member,
      owner: owner,
      group: group
    } do
      admin = create_admin_user()

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
        |> Ash.read_one!(actor: admin)

      assert admin_view_after.rsvp_count == 0
    end
  end

  defp create_verified_user do
    User
    |> Ash.Changeset.for_create(:create, %{
      email: "user#{System.unique_integer()}@example.com",
      display_name: "Test User",
      role: :user
    })
    |> Ash.create!(authorize?: false)
  end

  defp create_admin_user do
    User
    |> Ash.Changeset.for_create(:create, %{
      email: "admin#{System.unique_integer()}@example.com",
      display_name: "Admin User",
      role: :admin
    })
    |> Ash.create!(authorize?: false)
  end
end
