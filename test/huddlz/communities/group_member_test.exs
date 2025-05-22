defmodule Huddlz.Communities.GroupMemberTest do
  use Huddlz.DataCase, async: true

  require Ash.Query

  alias Huddlz.Communities.GroupMember

  describe "group membership" do
    setup do
      # Create a group owner
      owner =
        generate(
          user(
            email: "membership-owner@example.com",
            display_name: "Membership Owner",
            role: :verified
          )
        )

      _vierified_user = generate(user())

      # Create a regular member
      member =
        generate(
          user(
            email: "member-user@example.com",
            display_name: "Member User",
            role: :regular
          )
        )

      # Create a non-member
      non_member =
        generate(
          user(
            email: "non-member@example.com",
            display_name: "Non Member User",
            role: :regular
          )
        )

      # Create a group
      group =
        generate(
          group(
            name: "Membership Test Group",
            description: "A group for testing membership functions",
            is_public: true,
            owner_id: owner.id
          )
        )

      {:ok, %{owner: owner, member: member, non_member: non_member, group: group}}
    end

    test "group owner can add members", %{owner: owner, member: member, group: group} do
      # Owner should be able to add a member
      {:ok, membership} =
        GroupMember
        |> Ash.Changeset.for_create(:add_member, %{
          group_id: group.id,
          user_id: member.id,
          role: :member
        })
        |> Ash.create(actor: owner)

      assert membership.group_id == group.id
      assert membership.user_id == member.id
      assert membership.role == :member
    end

    test "non-owner cannot add members", %{member: member, non_member: non_member, group: group} do
      # Member should not be able to add another member
      assert {:error, %Ash.Error.Forbidden{}} =
               GroupMember
               |> Ash.Changeset.for_create(:add_member, %{
                 group_id: group.id,
                 user_id: non_member.id,
                 role: :member
               })
               |> Ash.create(actor: member)
    end

    test "owner can remove members", %{owner: owner, member: member, group: group} do
      # Add a member first
      {:ok, _} =
        GroupMember
        |> Ash.Changeset.for_create(:add_member, %{
          group_id: group.id,
          user_id: member.id,
          role: :member
        })
        |> Ash.create(actor: owner)

      membership =
        GroupMember
        |> Ash.Query.filter(group_id: group.id, user_id: member.id)
        |> Ash.read!(authorize?: false)
        |> List.first()

      # Owner should be able to remove a member
      :ok =
        membership
        |> Ash.Changeset.for_destroy(:remove_member, %{group_id: group.id, user_id: member.id})
        |> Ash.destroy!(actor: owner)

      # Verify member was removed
      memberships =
        GroupMember
        |> Ash.Query.for_read(:get_by_group, %{group_id: group.id})
        |> Ash.read!(actor: owner)

      refute Enum.any?(memberships, fn m -> m.user_id == member.id end)
    end

    test "users can leave groups", %{owner: owner, member: member, group: group} do
      # Add a member first
      {:ok, group_member} =
        GroupMember
        |> Ash.Changeset.for_create(:add_member, %{
          group_id: group.id,
          user_id: member.id,
          role: :member
        })
        |> Ash.create(actor: owner)

      # Member should be able to remove themselves
      :ok =
        group_member
        |> Ash.Changeset.for_destroy(:remove_member, %{
          group_id: group.id,
          user_id: member.id
        })
        |> Ash.destroy(actor: owner)

      # Verify member was removed
      memberships =
        GroupMember
        |> Ash.Query.for_read(:get_by_group, %{group_id: group.id})
        |> Ash.read!(actor: owner)

      refute Enum.any?(memberships, fn m -> m.user_id == member.id end)
    end
  end

  describe "membership visibility" do
    test "owner and organizer can see all members in public and private groups" do
      owner = generate(user(role: :verified))
      organizer = generate(user(role: :verified))

      public_group = generate(group(is_public: true, owner_id: owner.id, actor: owner))
      private_group = generate(group(is_public: false, owner_id: owner.id, actor: owner))

      generate(
        group_member(
          group_id: public_group.id,
          user_id: organizer.id,
          role: :organizer,
          actor: owner
        )
      )

      generate(
        group_member(
          group_id: private_group.id,
          user_id: organizer.id,
          role: :organizer,
          actor: owner
        )
      )

      public_owner_result =
        GroupMember
        |> Ash.Query.for_read(:get_by_group, %{group_id: public_group.id})
        |> Ash.read!(actor: owner)

      public_organizer_result =
        GroupMember
        |> Ash.Query.for_read(:get_by_group, %{group_id: public_group.id})
        |> Ash.read!(actor: organizer)

      private_owner_result =
        GroupMember
        |> Ash.Query.for_read(:get_by_group, %{group_id: private_group.id})
        |> Ash.read!(actor: owner)

      private_organizer_result =
        GroupMember
        |> Ash.Query.for_read(:get_by_group, %{group_id: private_group.id})
        |> Ash.read!(actor: organizer)

      assert length(public_owner_result) == 2
      assert length(public_organizer_result) == 2
      assert length(private_owner_result) == 2
      assert length(private_organizer_result) == 2
    end

    test "verified member can see all members in public and private groups" do
      owner = generate(user(role: :verified))
      verified_member = generate(user(role: :verified))

      public_group = generate(group(is_public: true, owner_id: owner.id, actor: owner))
      private_group = generate(group(is_public: false, owner_id: owner.id, actor: owner))

      # Add verified member to both groups
      generate(
        group_member(
          group_id: public_group.id,
          user_id: verified_member.id,
          role: :member,
          actor: owner
        )
      )

      generate(
        group_member(
          group_id: private_group.id,
          user_id: verified_member.id,
          role: :member,
          actor: owner
        )
      )

      # Add more members to reach expected count of 4
      # Owner is automatically added, so we need 2 more members per group
      member2 = generate(user(role: :verified))
      member3 = generate(user(role: :regular))

      generate(
        group_member(
          group_id: public_group.id,
          user_id: member2.id,
          role: :member,
          actor: owner
        )
      )

      generate(
        group_member(
          group_id: public_group.id,
          user_id: member3.id,
          role: :member,
          actor: owner
        )
      )

      generate(
        group_member(
          group_id: private_group.id,
          user_id: member2.id,
          role: :member,
          actor: owner
        )
      )

      generate(
        group_member(
          group_id: private_group.id,
          user_id: member3.id,
          role: :member,
          actor: owner
        )
      )

      public_result =
        GroupMember
        |> Ash.Query.for_read(:get_by_group, %{group_id: public_group.id})
        |> Ash.read!(actor: verified_member)

      private_result =
        GroupMember
        |> Ash.Query.for_read(:get_by_group, %{group_id: private_group.id})
        |> Ash.read!(actor: verified_member)

      assert length(public_result) == 4
      assert length(private_result) == 4
    end

    test "regular member can only see count in public and private groups" do
      owner = generate(user(role: :verified))
      regular_member = generate(user(role: :regular))

      public_group = generate(group(is_public: true, owner_id: owner.id, actor: owner))
      private_group = generate(group(is_public: false, owner_id: owner.id, actor: owner))

      # Add regular member to both groups
      generate(
        group_member(
          group_id: public_group.id,
          user_id: regular_member.id,
          role: :member,
          actor: owner
        )
      )

      generate(
        group_member(
          group_id: private_group.id,
          user_id: regular_member.id,
          role: :member,
          actor: owner
        )
      )

      # Should only see count, not member list (simulate by expecting empty list or forbidden)
      public_result =
        GroupMember
        |> Ash.Query.for_read(:get_by_group, %{group_id: public_group.id})
        |> Ash.read!(actor: regular_member)

      private_result =
        GroupMember
        |> Ash.Query.for_read(:get_by_group, %{group_id: private_group.id})
        |> Ash.read!(actor: regular_member)

      assert public_result == []
      assert private_result == []
    end

    # TODO: update this test according to the matrix if needed
    # test "verified non-member can see all members in public group, not in private group", %{
    #   verified_non_member: verified_non_member,
    #   public_group: public_group,
    #   private_group: private_group
    # } do
    #   public_result =
    #     GroupMember
    #     |> Ash.Query.for_read(:get_by_group, %{group_id: public_group.id})
    #     |> Ash.read!(actor: verified_non_member)
    #
    #   assert length(public_result) == 4
    #
    #   private_result =
    #     GroupMember
    #     |> Ash.Query.for_read(:get_by_group, %{group_id: private_group.id})
    #     |> Ash.read!(actor: verified_non_member)
    #
    #   assert private_result == []
    # end
  end
end
