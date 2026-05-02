defmodule Huddlz.Communities.GroupTest do
  use Huddlz.DataCase, async: true

  require Ash.Query

  alias Huddlz.Communities
  alias Huddlz.Communities.Group

  describe "group creation slug" do
    test "auto-generates slug from name when slug arg is omitted" do
      actor = generate(user())

      {:ok, group} =
        Group
        |> Ash.Changeset.for_create(
          :create_group,
          %{name: "Slug From Name Test", description: "x", is_public: true}
        )
        |> Ash.create(actor: actor)

      assert group.slug == Slug.slugify("Slug From Name Test")
    end

    test "preserves a caller-supplied slug" do
      actor = generate(user())

      {:ok, group} =
        Group
        |> Ash.Changeset.for_create(
          :create_group,
          %{
            name: "Custom Slug Test",
            description: "x",
            is_public: true,
            slug: "i-picked-this"
          }
        )
        |> Ash.create(actor: actor)

      assert group.slug == "i-picked-this"
    end

    test "blank slug arg falls through to name-derived" do
      actor = generate(user())

      {:ok, group} =
        Group
        |> Ash.Changeset.for_create(
          :create_group,
          %{name: "Blank Slug Test", description: "x", is_public: true, slug: ""}
        )
        |> Ash.create(actor: actor)

      assert group.slug == Slug.slugify("Blank Slug Test")
    end
  end

  describe "group creation" do
    test "admin users can create groups" do
      admin_user = generate(user(role: :admin))

      # Admin should be able to create a group
      {:ok, group} =
        Group
        |> Ash.Changeset.for_create(:create_group, %{
          name: "Admin Created Group",
          description: "A test group created by an admin",
          is_public: true
        })
        |> Ash.create(actor: admin_user)

      assert to_string(group.name) == "Admin Created Group"
      assert group.owner_id == admin_user.id
    end

    test "users can create groups" do
      verified_user = generate(user(role: :user))

      # Verified user should be able to create a group
      {:ok, group} =
        Group
        |> Ash.Changeset.for_create(:create_group, %{
          name: "Verified Created Group",
          description: "A test group created by a user",
          is_public: true
        })
        |> Ash.create(actor: verified_user)

      assert to_string(group.name) == "Verified Created Group"
      assert group.owner_id == verified_user.id
    end

    test "all users can create groups" do
      regular_user = generate(user(role: :user))

      # All users can now create groups
      assert {:ok, group} =
               Group
               |> Ash.Changeset.for_create(:create_group, %{
                 name: "Regular Created Group",
                 description: "A test group created by a user",
                 is_public: true
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
                 is_public: true
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

  describe "attribute constraints" do
    test "rejects description over 5000 characters" do
      owner = generate(user())
      long_desc = String.duplicate("a", 5001)

      assert {:error, _} =
               Group
               |> Ash.Changeset.for_create(:create_group, %{
                 name: "Test Group",
                 description: long_desc,
                 is_public: true
               })
               |> Ash.create(actor: owner)
    end

    test "rejects location over 500 characters" do
      owner = generate(user())
      long_loc = String.duplicate("a", 501)

      assert {:error, _} =
               Group
               |> Ash.Changeset.for_create(:create_group, %{
                 name: "Test Group",
                 location: long_loc,
                 is_public: true
               })
               |> Ash.create(actor: owner)
    end
  end

  describe "group management" do
    setup do
      owner = generate(user(role: :user))
      other_user = generate(user(role: :user))
      group = generate(group(name: "Test Management Group", owner_id: owner.id, actor: owner))

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

  describe "transfer_ownership" do
    setup do
      owner = generate(user(role: :user))
      group = generate(group(name: "Transfer Test", owner_id: owner.id, actor: owner))
      {:ok, %{owner: owner, group: group}}
    end

    test "owner can transfer ownership to an existing member", %{owner: owner, group: group} do
      new_owner = generate(user(role: :user))

      generate(
        group_member(
          group_id: group.id,
          user_id: new_owner.id,
          role: :member,
          actor: owner
        )
      )

      assert {:ok, transferred} =
               group
               |> Ash.Changeset.for_update(:transfer_ownership, %{new_owner_id: new_owner.id})
               |> Ash.update(actor: owner)

      assert transferred.owner_id == new_owner.id

      memberships =
        Huddlz.Communities.GroupMember
        |> Ash.Query.for_read(:get_by_group, %{group_id: group.id})
        |> Ash.read!(actor: new_owner)

      assert Enum.any?(memberships, &(&1.user_id == new_owner.id and &1.role == :owner))
      assert Enum.any?(memberships, &(&1.user_id == owner.id and &1.role == :organizer))
    end

    test "owner can transfer ownership to a non-member (auto-adds them)", %{
      owner: owner,
      group: group
    } do
      new_owner = generate(user(role: :user))

      assert {:ok, transferred} =
               group
               |> Ash.Changeset.for_update(:transfer_ownership, %{new_owner_id: new_owner.id})
               |> Ash.update(actor: owner)

      assert transferred.owner_id == new_owner.id

      new_owner_membership =
        Huddlz.Communities.GroupMember
        |> Ash.Query.filter(group_id: group.id, user_id: new_owner.id)
        |> Ash.read_one!(authorize?: false)

      assert new_owner_membership.role == :owner
    end

    test "non-owner cannot transfer ownership", %{group: group} do
      stranger = generate(user(role: :user))
      target = generate(user(role: :user))

      assert {:error, %Ash.Error.Forbidden{}} =
               group
               |> Ash.Changeset.for_update(:transfer_ownership, %{new_owner_id: target.id})
               |> Ash.update(actor: stranger)
    end

    test "rejects transferring ownership to the existing owner", %{owner: owner, group: group} do
      assert {:error, %Ash.Error.Invalid{}} =
               group
               |> Ash.Changeset.for_update(:transfer_ownership, %{new_owner_id: owner.id})
               |> Ash.update(actor: owner)
    end

    test "set_role action is forbidden through normal authorization", %{
      group: group,
      owner: owner
    } do
      member = generate(user(role: :user))

      {:ok, membership} =
        Huddlz.Communities.GroupMember
        |> Ash.Changeset.for_create(:add_member, %{
          group_id: group.id,
          user_id: member.id,
          role: :member
        })
        |> Ash.create(actor: owner)

      assert {:error, %Ash.Error.Forbidden{}} =
               membership
               |> Ash.Changeset.for_update(:set_role, %{role: :owner})
               |> Ash.update(actor: owner)
    end
  end

  describe "group search" do
    setup do
      # Create a user to own the groups
      owner = generate(user(role: :user))

      # Create some groups with distinctive names and descriptions for search testing
      {:ok, group1} =
        Group
        |> Ash.Changeset.for_create(:create_group, %{
          name: "Alpha Search Group",
          description: "This is the first test group for search",
          is_public: true
        })
        |> Ash.create(actor: owner)

      {:ok, group2} =
        Group
        |> Ash.Changeset.for_create(:create_group, %{
          name: "Beta Group",
          description: "This is a search test group with beta in the name",
          is_public: true
        })
        |> Ash.create(actor: owner)

      {:ok, group3} =
        Group
        |> Ash.Changeset.for_create(:create_group, %{
          name: "Gamma Group",
          description: "This group contains alpha in the description",
          is_public: true
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

  describe ":get_joined action" do
    setup do
      member = generate(user(role: :user))
      stranger = generate(user(role: :user))

      owned = generate(group(name: "Owned by member", actor: member, is_public: true))

      joined =
        generate(group(name: "Joined by member", actor: stranger, is_public: true))

      generate(group_member(group_id: joined.id, user_id: member.id, actor: stranger))

      _untouched =
        generate(group(name: "Unrelated", actor: stranger, is_public: true))

      %{member: member, stranger: stranger, owned: owned, joined: joined}
    end

    test "returns groups the actor has joined", %{member: member, joined: joined} do
      result = Communities.get_joined_groups!(actor: member)

      assert Enum.map(result, & &1.id) == [joined.id]
    end

    test "excludes groups the actor owns", %{member: member, owned: owned} do
      result = Communities.get_joined_groups!(actor: member)

      refute Enum.any?(result, &(&1.id == owned.id))
    end

    test "excludes groups the actor has no relationship to", %{
      member: member,
      stranger: stranger
    } do
      # The "Unrelated" group is owned by stranger and member is not a member.
      member_results = Communities.get_joined_groups!(actor: member)
      stranger_results = Communities.get_joined_groups!(actor: stranger)

      refute Enum.any?(member_results, &(&1.name |> to_string() == "Unrelated"))
      # Stranger owns Unrelated, so it's also excluded from THEIR joined list
      refute Enum.any?(stranger_results, &(&1.name |> to_string() == "Unrelated"))
    end

    test "returns nothing for an actor with no memberships" do
      lonely = generate(user(role: :user))

      assert Communities.get_joined_groups!(actor: lonely) == []
    end
  end
end
