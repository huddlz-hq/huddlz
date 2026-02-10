defmodule Huddlz.Communities.HuddlRsvpTest do
  use Huddlz.DataCase, async: true

  alias Huddlz.Communities.Group
  alias Huddlz.Communities.GroupMember
  alias Huddlz.Communities.Huddl
  alias Huddlz.Communities.HuddlAttendee

  require Ash.Query

  describe "RSVP functionality" do
    setup do
      owner = generate(user(role: :user))
      member = generate(user(role: :user))
      non_member = generate(user(role: :user))

      # Create group
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

      # Add member to group
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

      # Create a huddl
      huddl =
        Huddl
        |> Ash.Changeset.for_create(
          :create,
          %{
            title: "Test Huddl",
            description: "A test huddl",
            starts_at: DateTime.add(DateTime.utc_now(), 1, :day),
            ends_at: DateTime.add(DateTime.utc_now(), 2, :day),
            event_type: :virtual,
            virtual_link: "https://zoom.us/j/123456",
            is_private: false,
            group_id: group.id,
            creator_id: owner.id
          },
          actor: owner
        )
        |> Ash.create!()

      %{
        owner: owner,
        member: member,
        non_member: non_member,
        group: group,
        huddl: huddl
      }
    end

    test "member can RSVP to a huddl", %{member: member, huddl: huddl} do
      # RSVP to the huddl
      huddl
      |> Ash.Changeset.for_update(:rsvp, %{user_id: member.id}, actor: member)
      |> Ash.update!()

      assert rsvp_count(huddl) == 1

      # Check that attendee record was created
      attendees =
        HuddlAttendee
        |> Ash.Query.for_read(:by_huddl, %{huddl_id: huddl.id})
        |> Ash.read!(authorize?: false)

      assert length(attendees) == 1
      assert hd(attendees).user_id == member.id
    end

    test "non-member can RSVP to public huddl", %{non_member: non_member, huddl: huddl} do
      # RSVP to the huddl
      huddl
      |> Ash.Changeset.for_update(:rsvp, %{user_id: non_member.id}, actor: non_member)
      |> Ash.update!()

      assert rsvp_count(huddl) == 1
    end

    test "user cannot RSVP twice to the same huddl", %{member: member, huddl: huddl} do
      # First RSVP
      huddl
      |> Ash.Changeset.for_update(:rsvp, %{user_id: member.id}, actor: member)
      |> Ash.update!()

      # Second RSVP should not increase count
      huddl
      |> Ash.reload!()
      |> Ash.Changeset.for_update(:rsvp, %{user_id: member.id}, actor: member)
      |> Ash.update!()

      assert rsvp_count(huddl) == 1

      # Still only one attendee record
      attendees =
        HuddlAttendee
        |> Ash.Query.for_read(:by_huddl, %{huddl_id: huddl.id})
        |> Ash.read!(authorize?: false)

      assert length(attendees) == 1
    end

    test "multiple users can RSVP to the same huddl", %{
      member: member,
      owner: owner,
      huddl: huddl
    } do
      # Member RSVPs
      huddl
      |> Ash.Changeset.for_update(:rsvp, %{user_id: member.id}, actor: member)
      |> Ash.update!()

      # Owner RSVPs
      huddl
      |> Ash.reload!()
      |> Ash.Changeset.for_update(:rsvp, %{user_id: owner.id}, actor: owner)
      |> Ash.update!()

      assert rsvp_count(huddl) == 2

      # Check attendees
      attendees =
        HuddlAttendee
        |> Ash.Query.for_read(:by_huddl, %{huddl_id: huddl.id})
        |> Ash.read!(authorize?: false)

      assert length(attendees) == 2
      assert Enum.any?(attendees, &(&1.user_id == member.id))
      assert Enum.any?(attendees, &(&1.user_id == owner.id))
    end

    test "user cannot RSVP for someone else", %{member: member, owner: owner, huddl: huddl} do
      # Try to RSVP for someone else
      assert_raise Ash.Error.Forbidden, fn ->
        huddl
        |> Ash.Changeset.for_update(:rsvp, %{user_id: owner.id}, actor: member)
        |> Ash.update!()
      end
    end

    test "virtual link is only visible after RSVP", %{member: member, huddl: huddl} do
      # Before RSVP, virtual link should not be visible
      huddl_before =
        Huddl
        |> Ash.Query.filter(id: huddl.id)
        |> Ash.Query.load(:visible_virtual_link)
        |> Ash.read_one!(actor: member)

      assert huddl_before.visible_virtual_link == nil

      # After RSVP, virtual link should be visible
      huddl
      |> Ash.Changeset.for_update(:rsvp, %{user_id: member.id}, actor: member)
      |> Ash.update!()

      huddl_after =
        Huddl
        |> Ash.Query.filter(id: huddl.id)
        |> Ash.Query.load(:visible_virtual_link)
        |> Ash.read_one!(actor: member)

      assert huddl_after.visible_virtual_link == "https://zoom.us/j/123456"
    end

    test "user can check their RSVP status", %{member: member, huddl: huddl} do
      # Before RSVP
      result =
        HuddlAttendee
        |> Ash.Query.for_read(:check_rsvp, %{huddl_id: huddl.id, user_id: member.id})
        |> Ash.read_one(actor: member)

      assert {:ok, nil} = result

      # After RSVP
      huddl
      |> Ash.Changeset.for_update(:rsvp, %{user_id: member.id}, actor: member)
      |> Ash.update!()

      result =
        HuddlAttendee
        |> Ash.Query.for_read(:check_rsvp, %{huddl_id: huddl.id, user_id: member.id})
        |> Ash.read_one(actor: member)

      assert {:ok, %HuddlAttendee{}} = result
    end

    test "user can see their RSVPs", %{member: member, huddl: huddl} do
      # RSVP to the huddl
      huddl
      |> Ash.Changeset.for_update(:rsvp, %{user_id: member.id}, actor: member)
      |> Ash.update!()

      # Get user's RSVPs
      rsvps =
        HuddlAttendee
        |> Ash.Query.for_read(:by_user, %{user_id: member.id})
        |> Ash.read!(actor: member)

      assert length(rsvps) == 1
      assert hd(rsvps).huddl_id == huddl.id
    end

    test "cannot RSVP to private huddl in private group without membership" do
      owner = generate(user(role: :user))
      non_member = generate(user(role: :user))

      # Create private group
      private_group =
        Group
        |> Ash.Changeset.for_create(
          :create_group,
          %{
            name: "Private Group",
            description: "A private group",
            is_public: false,
            owner_id: owner.id
          },
          actor: owner
        )
        |> Ash.create!()

      # Create private huddl
      private_huddl =
        Huddl
        |> Ash.Changeset.for_create(
          :create,
          %{
            title: "Private Huddl",
            description: "A private huddl",
            starts_at: DateTime.add(DateTime.utc_now(), 1, :day),
            ends_at: DateTime.add(DateTime.utc_now(), 2, :day),
            event_type: :in_person,
            physical_location: "Secret Location",
            is_private: true,
            group_id: private_group.id,
            creator_id: owner.id
          },
          actor: owner
        )
        |> Ash.create!()

      # Non-member cannot even read the private huddl
      result =
        Huddl
        |> Ash.Query.filter(id: private_huddl.id)
        |> Ash.read_one(actor: non_member)

      assert {:ok, nil} = result
    end
  end

  describe "RSVP cancellation functionality" do
    setup do
      owner = generate(user(role: :user))
      member = generate(user(role: :user))
      other_user = generate(user(role: :user))

      # Create group
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

      # Add member to group
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

      # Create a huddl
      huddl =
        Huddl
        |> Ash.Changeset.for_create(
          :create,
          %{
            title: "Test Huddl",
            description: "A test huddl",
            starts_at: DateTime.add(DateTime.utc_now(), 1, :day),
            ends_at: DateTime.add(DateTime.utc_now(), 2, :day),
            event_type: :virtual,
            virtual_link: "https://zoom.us/j/123456",
            is_private: false,
            group_id: group.id,
            creator_id: owner.id
          },
          actor: owner
        )
        |> Ash.create!()

      %{
        owner: owner,
        member: member,
        other_user: other_user,
        group: group,
        huddl: huddl
      }
    end

    test "user can cancel their own RSVP", %{member: member, huddl: huddl} do
      # First RSVP to the huddl
      huddl
      |> Ash.Changeset.for_update(:rsvp, %{user_id: member.id}, actor: member)
      |> Ash.update!()

      # Verify RSVP exists
      assert rsvp_count(huddl) == 1

      # Cancel the RSVP
      huddl
      |> Ash.reload!()
      |> Ash.Changeset.for_update(:cancel_rsvp, %{user_id: member.id}, actor: member)
      |> Ash.update!()

      assert rsvp_count(huddl) == 0

      # Verify attendee record was deleted
      attendees =
        HuddlAttendee
        |> Ash.Query.for_read(:by_huddl, %{huddl_id: huddl.id})
        |> Ash.read!(authorize?: false)

      assert Enum.empty?(attendees)
    end

    test "cancelling RSVP when not RSVPed returns unchanged", %{member: member, huddl: huddl} do
      # Try to cancel without having RSVPed
      huddl
      |> Ash.Changeset.for_update(:cancel_rsvp, %{user_id: member.id}, actor: member)
      |> Ash.update!()

      assert rsvp_count(huddl) == 0
    end

    test "user cannot cancel someone else's RSVP", %{
      member: member,
      other_user: other_user,
      huddl: huddl
    } do
      # Member RSVPs
      huddl
      |> Ash.Changeset.for_update(:rsvp, %{user_id: member.id}, actor: member)
      |> Ash.update!()

      # Other user tries to cancel member's RSVP
      assert_raise Ash.Error.Forbidden, fn ->
        huddl
        |> Ash.reload!()
        |> Ash.Changeset.for_update(:cancel_rsvp, %{user_id: member.id}, actor: other_user)
        |> Ash.update!()
      end
    end

    test "multiple users can cancel their RSVPs independently", %{
      member: member,
      owner: owner,
      huddl: huddl
    } do
      # Both users RSVP
      huddl
      |> Ash.Changeset.for_update(:rsvp, %{user_id: member.id}, actor: member)
      |> Ash.update!()

      huddl
      |> Ash.reload!()
      |> Ash.Changeset.for_update(:rsvp, %{user_id: owner.id}, actor: owner)
      |> Ash.update!()

      assert rsvp_count(huddl) == 2

      # Member cancels their RSVP
      huddl
      |> Ash.reload!()
      |> Ash.Changeset.for_update(:cancel_rsvp, %{user_id: member.id}, actor: member)
      |> Ash.update!()

      assert rsvp_count(huddl) == 1

      # Owner cancels their RSVP
      huddl
      |> Ash.reload!()
      |> Ash.Changeset.for_update(:cancel_rsvp, %{user_id: owner.id}, actor: owner)
      |> Ash.update!()

      assert rsvp_count(huddl) == 0
    end

    test "user can RSVP again after cancelling", %{member: member, huddl: huddl} do
      # RSVP
      huddl
      |> Ash.Changeset.for_update(:rsvp, %{user_id: member.id}, actor: member)
      |> Ash.update!()

      # Cancel
      huddl
      |> Ash.reload!()
      |> Ash.Changeset.for_update(:cancel_rsvp, %{user_id: member.id}, actor: member)
      |> Ash.update!()

      # RSVP again
      huddl
      |> Ash.reload!()
      |> Ash.Changeset.for_update(:rsvp, %{user_id: member.id}, actor: member)
      |> Ash.update!()

      assert rsvp_count(huddl) == 1

      # Verify attendee record exists
      attendees =
        HuddlAttendee
        |> Ash.Query.for_read(:by_huddl, %{huddl_id: huddl.id})
        |> Ash.read!(authorize?: false)

      assert length(attendees) == 1
      assert hd(attendees).user_id == member.id
    end
  end

  describe "attendee list authorization" do
    setup do
      owner = generate(user(role: :user))
      organizer = generate(user(role: :user))
      member = generate(user(role: :user))
      attendee = generate(user(role: :user))
      non_attendee = generate(user(role: :user))

      # Create group
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

      # Add organizer to group
      GroupMember
      |> Ash.Changeset.for_create(
        :add_member,
        %{
          group_id: group.id,
          user_id: organizer.id,
          role: "organizer"
        },
        actor: owner
      )
      |> Ash.create!()

      # Add member to group
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

      # Create huddl
      huddl =
        Huddl
        |> Ash.Changeset.for_create(
          :create,
          %{
            title: "Test Huddl",
            description: "A test huddl",
            starts_at: DateTime.add(DateTime.utc_now(), 1, :day),
            ends_at: DateTime.add(DateTime.utc_now(), 2, :day),
            event_type: :virtual,
            virtual_link: "https://zoom.us/j/123456",
            is_private: false,
            group_id: group.id,
            creator_id: owner.id
          },
          actor: owner
        )
        |> Ash.create!()

      # Have attendee RSVP to the huddl
      huddl
      |> Ash.Changeset.for_update(:rsvp, %{user_id: attendee.id}, actor: attendee)
      |> Ash.update!()

      %{
        owner: owner,
        organizer: organizer,
        member: member,
        attendee: attendee,
        non_attendee: non_attendee,
        group: group,
        huddl: huddl
      }
    end

    test "attendee can see attendee list", %{attendee: attendee, huddl: huddl} do
      # Attendee can see who's attending
      result =
        HuddlAttendee
        |> Ash.Query.for_read(:by_huddl, %{huddl_id: huddl.id})
        |> Ash.read(actor: attendee)

      assert {:ok, attendees} = result
      assert length(attendees) == 1
      assert hd(attendees).user_id == attendee.id
    end

    test "group owner can see attendee list", %{owner: owner, huddl: huddl, attendee: attendee} do
      # Group owner can see who's attending
      result =
        HuddlAttendee
        |> Ash.Query.for_read(:by_huddl, %{huddl_id: huddl.id})
        |> Ash.read(actor: owner)

      assert {:ok, attendees} = result
      assert length(attendees) == 1
      assert hd(attendees).user_id == attendee.id
    end

    test "group organizer can see attendee list", %{
      organizer: organizer,
      huddl: huddl,
      attendee: attendee
    } do
      # Group organizer can see who's attending
      result =
        HuddlAttendee
        |> Ash.Query.for_read(:by_huddl, %{huddl_id: huddl.id})
        |> Ash.read(actor: organizer)

      assert {:ok, attendees} = result
      assert length(attendees) == 1
      assert hd(attendees).user_id == attendee.id
    end

    test "group member who is not attending cannot see attendee list", %{
      member: member,
      huddl: huddl
    } do
      # Group member who hasn't RSVPed cannot see attendee list
      result =
        HuddlAttendee
        |> Ash.Query.for_read(:by_huddl, %{huddl_id: huddl.id})
        |> Ash.read(actor: member)

      assert {:ok, []} = result
    end

    test "non-attendee cannot see attendee list", %{non_attendee: non_attendee, huddl: huddl} do
      # Non-attendee cannot see attendee list
      result =
        HuddlAttendee
        |> Ash.Query.for_read(:by_huddl, %{huddl_id: huddl.id})
        |> Ash.read(actor: non_attendee)

      assert {:ok, []} = result
    end

    test "anonymous user cannot see attendee list", %{huddl: huddl} do
      # Anonymous user cannot see attendee list
      result =
        HuddlAttendee
        |> Ash.Query.for_read(:by_huddl, %{huddl_id: huddl.id})
        |> Ash.read(actor: nil)

      assert {:ok, []} = result
    end

    test "admin can see attendee list", %{huddl: huddl, attendee: attendee} do
      admin = generate(user(role: :admin))

      # Admin can see attendee list
      result =
        HuddlAttendee
        |> Ash.Query.for_read(:by_huddl, %{huddl_id: huddl.id})
        |> Ash.read(actor: admin)

      assert {:ok, attendees} = result
      assert length(attendees) == 1
      assert hd(attendees).user_id == attendee.id
    end
  end

  # Helper to load the rsvp_count aggregate from the database
  defp rsvp_count(huddl) do
    huddl |> Ash.reload!() |> Ash.load!(:rsvp_count, authorize?: false) |> Map.get(:rsvp_count)
  end
end
