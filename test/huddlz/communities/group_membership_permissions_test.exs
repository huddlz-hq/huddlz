defmodule Huddlz.Communities.GroupMembershipPermissionsTest do
  use Huddlz.DataCase, async: true

  alias Huddlz.Communities.GroupMember

  require Ash.Query

  setup do
    admin = generate(user(role: :admin))
    verified = generate(user())
    regular = generate(user())
    outsider = generate(user())

    # Groups are automatically created with owner membership
    public_group =
      generate(
        group(name: "Public Group", is_public: true, owner_id: verified.id, actor: verified)
      )

    private_group =
      generate(
        group(name: "Private Group", is_public: false, owner_id: verified.id, actor: verified)
      )

    %{
      admin: admin,
      verified: verified,
      regular: regular,
      outsider: outsider,
      public_group: public_group,
      private_group: private_group
    }
  end

  describe "join_group action" do
    test "user cannot join private group", %{regular: user, private_group: group} do
      assert {:error, %Ash.Error.Forbidden{}} =
               GroupMember
               |> Ash.Changeset.for_create(:join_group, %{group_id: group.id, user_id: user.id},
                 actor: user
               )
               |> Ash.create()
    end

    test "user can join public group", %{public_group: group} do
      # Create a new user who isn't already a member
      new_verified = generate(user())

      assert {:ok, membership} =
               GroupMember
               |> Ash.Changeset.for_create(
                 :join_group,
                 %{group_id: group.id, user_id: new_verified.id},
                 actor: new_verified
               )
               |> Ash.create()

      assert membership.role == :member
    end
  end

  describe "add_member action" do
    test "user cannot add organizer to group", %{regular: user, public_group: group} do
      new_verified = generate(user())

      assert {:error, %Ash.Error.Forbidden{}} =
               GroupMember
               |> Ash.Changeset.for_create(
                 :add_member,
                 %{group_id: group.id, user_id: new_verified.id, role: :organizer},
                 actor: user
               )
               |> Ash.create()
    end

    test "user (non-owner member) cannot add organizer to group", %{
      verified: owner,
      public_group: group
    } do
      # Create a new user who is not the owner
      new_verified_member = generate(user(role: :user))
      new_verified_to_add = generate(user(role: :user))

      # Add new_verified_member as a regular member first
      generate(
        group_member(
          group_id: group.id,
          user_id: new_verified_member.id,
          role: :member,
          actor: owner
        )
      )

      # Regular member cannot add organizer
      assert {:error, %Ash.Error.Forbidden{}} =
               GroupMember
               |> Ash.Changeset.for_create(
                 :add_member,
                 %{group_id: group.id, user_id: new_verified_to_add.id, role: :organizer},
                 actor: new_verified_member
               )
               |> Ash.create()
    end

    test "group owner can add organizer to group", %{verified: owner, public_group: group} do
      new_verified = generate(user())

      assert {:ok, membership} =
               GroupMember
               |> Ash.Changeset.for_create(
                 :add_member,
                 %{group_id: group.id, user_id: new_verified.id, role: :organizer},
                 actor: owner
               )
               |> Ash.create()

      assert membership.role == :organizer
    end
  end

  describe "get_by_group read action" do
    test "verified non-member can see member list in public group", %{
      public_group: group,
      verified: user
    } do
      result =
        GroupMember
        |> Ash.Query.for_read(:get_by_group, %{group_id: group.id})
        |> Ash.read!(actor: user)

      assert length(result) > 0
    end

    test "regular non-member cannot see member list in public group", %{
      public_group: group,
      regular: user
    } do
      result =
        GroupMember
        |> Ash.Query.for_read(:get_by_group, %{group_id: group.id})
        |> Ash.read!(actor: user)

      # Non-members cannot see member lists
      assert result == []
    end

    test "verified non-member cannot see member list in private group", %{private_group: group} do
      # Create a new user who is not a member
      non_member = generate(user(role: :user))

      result =
        GroupMember
        |> Ash.Query.for_read(:get_by_group, %{group_id: group.id})
        |> Ash.read!(actor: non_member)

      assert result == []
    end

    test "regular member can see full member list", %{
      public_group: group,
      regular: user,
      verified: owner
    } do
      # Add user as member (owner must add them)
      {:ok, _} =
        GroupMember
        |> Ash.Changeset.for_create(
          :add_member,
          %{group_id: group.id, user_id: user.id, role: :member},
          actor: owner
        )
        |> Ash.create()

      result =
        GroupMember
        |> Ash.Query.for_read(:get_by_group, %{group_id: group.id})
        |> Ash.read!(actor: user)

      # Owner and member
      assert length(result) == 2
    end

    test "organizer can see all members in public group", %{public_group: group, verified: owner} do
      # Add a new user as organizer
      new_organizer = generate(user(role: :user))

      {:ok, _} =
        GroupMember
        |> Ash.Changeset.for_create(
          :add_member,
          %{group_id: group.id, user_id: new_organizer.id, role: :organizer},
          actor: owner
        )
        |> Ash.create()

      result =
        GroupMember
        |> Ash.Query.for_read(:get_by_group, %{group_id: group.id})
        |> Ash.read!(actor: new_organizer)

      assert Enum.any?(result, fn m -> m.role == :owner end)
      assert Enum.any?(result, fn m -> m.role == :organizer end)
    end
  end

  describe "remove_member action" do
    test "owner can remove member", %{public_group: group, verified: owner, regular: member} do
      # Add user as member
      {:ok, membership} =
        GroupMember
        |> Ash.Changeset.for_create(
          :add_member,
          %{group_id: group.id, user_id: member.id, role: :member},
          actor: owner
        )
        |> Ash.create()

      :ok =
        membership
        |> Ash.Changeset.for_destroy(:remove_member, %{group_id: group.id, user_id: member.id})
        |> Ash.destroy(actor: owner)

      result =
        GroupMember
        |> Ash.Query.for_read(:get_by_group, %{group_id: group.id})
        |> Ash.read!(actor: owner)

      refute Enum.any?(result, fn m -> m.user_id == member.id end)
    end

    test "member cannot remove another member", %{
      public_group: group,
      verified: owner,
      regular: member
    } do
      # Create another user to be removed
      another_member = generate(user(role: :user))

      # Add both as members
      {:ok, _} =
        GroupMember
        |> Ash.Changeset.for_create(
          :add_member,
          %{group_id: group.id, user_id: member.id, role: :member},
          actor: owner
        )
        |> Ash.create()

      {:ok, membership} =
        GroupMember
        |> Ash.Changeset.for_create(
          :add_member,
          %{group_id: group.id, user_id: another_member.id, role: :member},
          actor: owner
        )
        |> Ash.create()

      assert {:error, %Ash.Error.Forbidden{}} =
               membership
               |> Ash.Changeset.for_destroy(:remove_member, %{
                 group_id: group.id,
                 user_id: another_member.id
               })
               |> Ash.destroy(actor: member)
    end
  end
end
