defmodule Huddlz.Communities.GroupMembershipTest do
  use Huddlz.DataCase, async: true

  alias Huddlz.Communities.Group
  alias Huddlz.Communities.GroupMember

  require Ash.Query

  describe "join_group/2" do
    setup do
      admin = generate(user(role: :admin))
      verified_user = generate(user(role: :user))
      regular_user = generate(user(role: :user))

      public_group = generate(group(is_public: true, owner_id: admin.id, actor: admin))
      private_group = generate(group(is_public: false, owner_id: admin.id, actor: admin))

      %{
        admin: admin,
        verified_user: verified_user,
        regular_user: regular_user,
        public_group: public_group,
        private_group: private_group
      }
    end

    test "user can join public group", %{verified_user: user, public_group: group} do
      assert {:ok, membership} =
               GroupMember
               |> Ash.Changeset.for_create(:join_group, %{group_id: group.id}, actor: user)
               |> Ash.create()

      assert membership.user_id == user.id
      assert membership.group_id == group.id
      assert membership.role == :member
    end

    test "user cannot join private group", %{verified_user: user, private_group: group} do
      assert {:error, _} =
               GroupMember
               |> Ash.Changeset.for_create(:join_group, %{group_id: group.id}, actor: user)
               |> Ash.create()
    end

    test "join_group always relates to the actor — user_id input is rejected", %{
      verified_user: user,
      regular_user: other_user,
      public_group: group
    } do
      # The action no longer accepts user_id; passing it is a NoSuchInput error.
      assert {:error, _} =
               GroupMember
               |> Ash.Changeset.for_create(
                 :join_group,
                 %{group_id: group.id, user_id: other_user.id},
                 actor: user
               )
               |> Ash.create()
    end
  end

  describe "leave_group/2" do
    setup do
      admin = generate(user(role: :admin))
      verified_user = generate(user(role: :user))

      public_group = generate(group(is_public: true, owner_id: admin.id, actor: admin))

      # Add verified_user to the group
      {:ok, _} =
        GroupMember
        |> Ash.Changeset.for_create(
          :add_member,
          %{
            group_id: public_group.id,
            user_id: verified_user.id,
            role: "member"
          },
          authorize?: false
        )
        |> Ash.create()

      %{
        admin: admin,
        verified_user: verified_user,
        public_group: public_group
      }
    end

    test "member can leave group", %{verified_user: user, public_group: group} do
      membership =
        GroupMember
        |> Ash.Query.filter(group_id == ^group.id and user_id == ^user.id)
        |> Ash.read_one!(authorize?: false)

      assert :ok = Ash.destroy(membership, action: :leave_group, actor: user)

      # Verify member was removed
      assert {:ok, nil} ==
               GroupMember
               |> Ash.Query.filter(group_id == ^group.id and user_id == ^user.id)
               |> Ash.read_one(authorize?: false)
    end

    test "owner cannot leave their own group" do
      # Use a non-admin owner so the admin bypass policy does not mask the
      # owner-role guard. Owners would otherwise destroy their owner-role
      # membership row, leaving the group with a stale owner_id and locking
      # themselves out of private groups (Group :read requires public OR a
      # member relationship). To leave, an owner must transfer ownership
      # first via Group.:transfer_ownership.
      owner = generate(user(role: :user))
      group = generate(group(is_public: true, owner_id: owner.id, actor: owner))

      owner_membership =
        GroupMember
        |> Ash.Query.filter(group_id == ^group.id and user_id == ^owner.id)
        |> Ash.read_one!(authorize?: false)

      assert owner_membership.role == :owner

      assert {:error, %Ash.Error.Forbidden{}} =
               Ash.destroy(owner_membership, action: :leave_group, actor: owner)

      # Membership row is still there
      assert {:ok, %GroupMember{}} =
               GroupMember
               |> Ash.Query.filter(group_id == ^group.id and user_id == ^owner.id)
               |> Ash.read_one(authorize?: false)
    end

    test "admin owner can still leave via the admin bypass", %{admin: owner, public_group: group} do
      # The admin bypass at the top of GroupMember.policies trumps the
      # owner-role guard. Documented here to make the bypass interaction
      # explicit and to prevent accidental tightening that would also lock
      # admins out of recovery paths.
      owner_membership =
        GroupMember
        |> Ash.Query.filter(group_id == ^group.id and user_id == ^owner.id)
        |> Ash.read_one!(authorize?: false)

      assert :ok = Ash.destroy(owner_membership, action: :leave_group, actor: owner)
    end

    test "user cannot remove someone else", %{
      verified_user: user,
      admin: owner,
      public_group: group
    } do
      owner_membership =
        GroupMember
        |> Ash.Query.filter(group_id == ^group.id and user_id == ^owner.id)
        |> Ash.read_one!(authorize?: false)

      assert {:error, _} = Ash.destroy(owner_membership, action: :leave_group, actor: user)
    end
  end

  describe "group creator membership" do
    test "owner is automatically added as member when creating group" do
      admin = generate(user(role: :admin))

      {:ok, group} =
        Group
        |> Ash.Changeset.for_create(
          :create_group,
          %{
            name: "Test Group",
            description: "Test",
            is_public: true
          },
          actor: admin
        )
        |> Ash.create()

      # Check that owner is a member
      assert membership =
               GroupMember
               |> Ash.Query.filter(group_id == ^group.id and user_id == ^admin.id)
               |> Ash.read_one!(authorize?: false)

      assert membership.role == :owner
    end
  end
end
