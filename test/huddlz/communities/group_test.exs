defmodule Huddlz.Communities.GroupTest do
  use Huddlz.DataCase, async: true

  alias Huddlz.Accounts.User
  alias Huddlz.Communities
  alias Huddlz.Communities.Group

  describe "group creation" do
    test "admin users can create groups" do
      # Create an admin user
      admin_user =
        Ash.Seed.seed!(User, %{
          email: "admin-group-creation@example.com",
          display_name: "Admin Group Creator",
          role: :admin
        })

      # Admin should be able to create a group
      {:ok, group} =
        Group
        |> Ash.Changeset.for_create(:create_group, %{
          name: "Admin Created Group",
          description: "A test group created by an admin",
          is_public: true,
          owner_id: admin_user.id
        })
        |> Ash.create(actor: admin_user)

      assert to_string(group.name) == "Admin Created Group"
      assert group.owner_id == admin_user.id
    end

    test "users can create groups" do
      # Create a user
      verified_user =
        Ash.Seed.seed!(User, %{
          email: "verified-group-creation@example.com",
          display_name: "Verified Group Creator",
          role: :user
        })

      # Verified user should be able to create a group
      {:ok, group} =
        Group
        |> Ash.Changeset.for_create(:create_group, %{
          name: "Verified Created Group",
          description: "A test group created by a user",
          is_public: true,
          owner_id: verified_user.id
        })
        |> Ash.create(actor: verified_user)

      assert to_string(group.name) == "Verified Created Group"
      assert group.owner_id == verified_user.id
    end

    test "all users can create groups" do
      # Create a user
      regular_user =
        Ash.Seed.seed!(User, %{
          email: "regular-group-creation@example.com",
          display_name: "Regular Group Creator",
          role: :user
        })

      # All users can now create groups
      assert {:ok, group} =
               Group
               |> Ash.Changeset.for_create(:create_group, %{
                 name: "Regular Created Group",
                 description: "A test group created by a user",
                 is_public: true,
                 owner_id: regular_user.id
               })
               |> Ash.create(actor: regular_user)

      assert to_string(group.name) == "Regular Created Group"
    end
  end

  describe "group visibility and member access" do
    test "anyone can read public groups" do
      public_group = generate(group(is_public: true))
      # All users should be able to read the public group
      admin_user = generate(user(role: :admin))
      {:ok, _} = Ash.get(Group, public_group.id, actor: admin_user)

      verified_user = generate(user(role: :user))
      {:ok, _} = Ash.get(Group, public_group.id, actor: verified_user)

      regular_user = generate(user(role: :user))
      {:ok, _} = Ash.get(Group, public_group.id, actor: regular_user)
    end

    test "admin can read private groups" do
      private_group = generate(group(is_public: false))

      # Admin can read the private group
      admin_user = generate(user(role: :admin))
      assert {:ok, _} = Ash.get(Group, private_group.id, actor: admin_user)
    end

    test "non-admin cannot see private groups" do
      private_group = generate(group(is_public: false))

      # Regular user should not be able to read the private group
      regular_user = generate(user(role: :user))

      assert {:error, _error} =
               Ash.get(Group, private_group.id, actor: regular_user)
    end

    test "members of private group can see the group" do
      owner = generate(user(role: :user))
      private_group = generate(group(is_public: false, owner_id: owner.id, actor: owner))

      # Regular user should not be able to read the private group
      regular_user = generate(user(role: :user))

      _group_membership =
        generate(group_member(group_id: private_group.id, user_id: regular_user.id, actor: owner))

      assert {:ok, _} = Ash.get(Group, private_group.id, actor: regular_user)
    end

    test "all users can be assigned as owner" do
      regular_user = generate(user())

      # All users can now create groups and be owners
      assert {:ok, group} =
               Group
               |> Ash.Changeset.for_create(:create_group, %{
                 name: "User Owned Group",
                 description: "A group owned by a regular user",
                 is_public: true,
                 owner_id: regular_user.id
               })
               |> Ash.create(actor: regular_user)

      assert group.owner_id == regular_user.id
    end

    test "all users can be assigned as organizer" do
      owner = generate(user(role: :user))
      public_group = generate(group(is_public: true, owner_id: owner.id, actor: owner))
      _verified_user = generate(user(role: :user))
      regular_user2 = generate(user(role: :user))
      # All users can now be organizers
      {:ok, _member} =
        Huddlz.Communities.GroupMember
        |> Ash.Changeset.for_create(:add_member, %{
          group_id: public_group.id,
          user_id: regular_user2.id,
          role: "organizer"
        })
        |> Ash.create(actor: owner)
    end

    test "member visibility follows access control rules for public groups" do
      # Create users
      owner = generate(user(role: :user))
      verified_member = generate(user(role: :user))
      organizer = generate(user(role: :user))
      regular_non_member = generate(user(role: :user))
      regular_member = generate(user(role: :user))
      verified_non_member = generate(user(role: :user))

      # Create public group
      public_group = generate(group(is_public: true, owner_id: owner.id, actor: owner))

      # Add members
      generate(
        group_member(
          group_id: public_group.id,
          user_id: verified_member.id,
          role: "member",
          actor: owner
        )
      )

      generate(
        group_member(
          group_id: public_group.id,
          user_id: organizer.id,
          role: "organizer",
          actor: owner
        )
      )

      generate(
        group_member(
          group_id: public_group.id,
          user_id: regular_member.id,
          role: "member",
          actor: owner
        )
      )

      # Only members can see member lists
      members_owner =
        Huddlz.Communities.GroupMember
        |> Ash.Query.for_read(:get_by_group, %{group_id: public_group.id})
        |> Ash.read!(actor: owner)

      members_organizer =
        Huddlz.Communities.GroupMember
        |> Ash.Query.for_read(:get_by_group, %{group_id: public_group.id})
        |> Ash.read!(actor: organizer)

      members_verified =
        Huddlz.Communities.GroupMember
        |> Ash.Query.for_read(:get_by_group, %{group_id: public_group.id})
        |> Ash.read!(actor: verified_member)

      # Non-members cannot see members of public groups
      verified_non_member_view =
        Huddlz.Communities.GroupMember
        |> Ash.Query.for_read(:get_by_group, %{group_id: public_group.id})
        |> Ash.read!(actor: verified_non_member)

      # Members should see the same member list (owner + organizer + verified_member + regular_member = 4)
      assert length(members_owner) == 4
      assert length(members_organizer) == 4
      assert length(members_verified) == 4
      # Non-members see empty list
      assert verified_non_member_view == []

      # Regular members can see members
      regular_member_result =
        Huddlz.Communities.GroupMember
        |> Ash.Query.for_read(:get_by_group, %{group_id: public_group.id})
        |> Ash.read!(actor: regular_member)

      assert length(regular_member_result) == 4

      # Non-members cannot see members
      regular_non_member_result =
        Huddlz.Communities.GroupMember
        |> Ash.Query.for_read(:get_by_group, %{group_id: public_group.id})
        |> Ash.read!(actor: regular_non_member)

      assert regular_non_member_result == []
    end

    test "member visibility follows access control rules for private groups" do
      # Create users
      owner = generate(user(role: :user))
      verified_member = generate(user(role: :user))
      organizer = generate(user(role: :user))
      regular_member = generate(user(role: :user))
      verified_non_member = generate(user(role: :user))
      regular_non_member = generate(user(role: :user))

      # Create private group
      private_group = generate(group(is_public: false, owner_id: owner.id, actor: owner))
      # Add members to private group
      generate(
        group_member(
          group_id: private_group.id,
          user_id: verified_member.id,
          role: "member",
          actor: owner
        )
      )

      generate(
        group_member(
          group_id: private_group.id,
          user_id: organizer.id,
          role: "organizer",
          actor: owner
        )
      )

      generate(
        group_member(
          group_id: private_group.id,
          user_id: regular_member.id,
          role: "member",
          actor: owner
        )
      )

      # Owner can see all members
      members_owner =
        Huddlz.Communities.GroupMember
        |> Ash.Query.for_read(:get_by_group, %{group_id: private_group.id})
        |> Ash.read!(actor: owner)

      # Organizer can see all members
      members_organizer =
        Huddlz.Communities.GroupMember
        |> Ash.Query.for_read(:get_by_group, %{group_id: private_group.id})
        |> Ash.read!(actor: organizer)

      # Verified member can see all members
      members_verified =
        Huddlz.Communities.GroupMember
        |> Ash.Query.for_read(:get_by_group, %{group_id: private_group.id})
        |> Ash.read!(actor: verified_member)

      # All should see the same member list
      assert length(members_owner) == 4
      assert length(members_organizer) == 4
      assert length(members_verified) == 4

      # Regular member can now see members
      regular_member_result =
        Huddlz.Communities.GroupMember
        |> Ash.Query.for_read(:get_by_group, %{group_id: private_group.id})
        |> Ash.read!(actor: regular_member)

      assert length(regular_member_result) == 4

      # Verified non-member should not be able to see members of private groups
      verified_non_member_result =
        Huddlz.Communities.GroupMember
        |> Ash.Query.for_read(:get_by_group, %{group_id: private_group.id})
        |> Ash.read!(actor: verified_non_member)

      assert verified_non_member_result == []

      # Regular non-member should not be able to see members
      regular_non_member_result =
        Huddlz.Communities.GroupMember
        |> Ash.Query.for_read(:get_by_group, %{group_id: private_group.id})
        |> Ash.read!(actor: regular_non_member)

      assert regular_non_member_result == []
    end
  end

  describe "group management" do
    setup do
      # Create a group owner
      owner =
        Ash.Seed.seed!(User, %{
          email: "group-owner@example.com",
          display_name: "Group Owner",
          role: :user
        })

      # Create another user
      other_user =
        Ash.Seed.seed!(User, %{
          email: "other-user@example.com",
          display_name: "Other User",
          role: :user
        })

      # Create a group
      {:ok, group} =
        Group
        |> Ash.Changeset.for_create(:create_group, %{
          name: "Test Management Group",
          description: "A group for testing management functions",
          is_public: true,
          owner_id: owner.id
        })
        |> Ash.create(actor: owner)

      {:ok, %{owner: owner, other_user: other_user, group: group}}
    end

    test "owner can update group details", %{owner: owner, group: group} do
      # Update the group name
      {:ok, updated_group} =
        group
        |> Ash.Changeset.for_update(:update_details, %{
          name: "Updated Group Name"
        })
        |> Ash.update(actor: owner)

      assert to_string(updated_group.name) == "Updated Group Name"
    end

    test "non-owner cannot update group details", %{other_user: other_user, group: group} do
      # Non-owner should not be able to update the group
      {:error, %Ash.Error.Forbidden{}} =
        group
        |> Ash.Changeset.for_update(:update_details, %{
          name: "Unauthorized Update"
        })
        |> Ash.update(actor: other_user)
    end
  end

  describe "group search" do
    setup do
      # Create a user to own the groups
      owner =
        Ash.Seed.seed!(User, %{
          email: "search-test-owner@example.com",
          display_name: "Search Test Owner",
          role: :user
        })

      # Create some groups with distinctive names and descriptions for search testing
      {:ok, group1} =
        Group
        |> Ash.Changeset.for_create(:create_group, %{
          name: "Alpha Search Group",
          description: "This is the first test group for search",
          is_public: true,
          owner_id: owner.id
        })
        |> Ash.create(actor: owner)

      {:ok, group2} =
        Group
        |> Ash.Changeset.for_create(:create_group, %{
          name: "Beta Group",
          description: "This is a search test group with beta in the name",
          is_public: true,
          owner_id: owner.id
        })
        |> Ash.create(actor: owner)

      {:ok, group3} =
        Group
        |> Ash.Changeset.for_create(:create_group, %{
          name: "Gamma Group",
          description: "This group contains alpha in the description",
          is_public: true,
          owner_id: owner.id
        })
        |> Ash.create(actor: owner)

      {:ok, %{owner: owner, group1: group1, group2: group2, group3: group3}}
    end

    test "search finds groups by name", %{owner: owner} do
      result = Communities.search_groups!("Alpha", actor: owner)
      assert length(result) == 2
      assert hd(result).name |> to_string() == "Alpha Search Group"
    end

    test "search finds groups by description", %{owner: owner, group1: group1, group3: group3} do
      # Direct test on resource
      result =
        Huddlz.Communities.Group
        |> Ash.Query.for_read(:search, %{query: "alpha"})
        |> Ash.read!(actor: owner)

      assert length(result) == 2
      group_ids = Enum.map(result, & &1.id) |> MapSet.new()

      # Verify both groups are found
      # Alpha in name
      assert MapSet.member?(group_ids, group1.id)
      # alpha in description
      assert MapSet.member?(group_ids, group3.id)
    end
  end
end
