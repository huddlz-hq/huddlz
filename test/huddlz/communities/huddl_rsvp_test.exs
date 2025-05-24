defmodule Huddlz.Communities.HuddlRsvpTest do
  use Huddlz.DataCase, async: true

  alias Huddlz.Accounts.User
  alias Huddlz.Communities.Group
  alias Huddlz.Communities.GroupMember
  alias Huddlz.Communities.Huddl
  alias Huddlz.Communities.HuddlAttendee

  require Ash.Query

  describe "RSVP functionality" do
    setup do
      # Create users
      owner = create_verified_user()
      member = create_verified_user()
      non_member = create_verified_user()

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
      updated_huddl =
        huddl
        |> Ash.Changeset.for_update(:rsvp, %{user_id: member.id}, actor: member)
        |> Ash.update!()

      assert updated_huddl.rsvp_count == 1

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
      updated_huddl =
        huddl
        |> Ash.Changeset.for_update(:rsvp, %{user_id: non_member.id}, actor: non_member)
        |> Ash.update!()

      assert updated_huddl.rsvp_count == 1
    end

    test "user cannot RSVP twice to the same huddl", %{member: member, huddl: huddl} do
      # First RSVP
      huddl
      |> Ash.Changeset.for_update(:rsvp, %{user_id: member.id}, actor: member)
      |> Ash.update!()

      # Second RSVP should not increase count
      updated_huddl =
        huddl
        |> Ash.reload!()
        |> Ash.Changeset.for_update(:rsvp, %{user_id: member.id}, actor: member)
        |> Ash.update!()

      assert updated_huddl.rsvp_count == 1

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
      updated_huddl =
        huddl
        |> Ash.reload!()
        |> Ash.Changeset.for_update(:rsvp, %{user_id: owner.id}, actor: owner)
        |> Ash.update!()

      assert updated_huddl.rsvp_count == 2

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
      owner = create_verified_user()
      non_member = create_verified_user()

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

  defp create_verified_user do
    User
    |> Ash.Changeset.for_create(:create, %{
      email: "user#{System.unique_integer()}@example.com",
      display_name: "Test User",
      role: :verified
    })
    |> Ash.create!(authorize?: false)
  end
end
