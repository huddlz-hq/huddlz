defmodule Huddlz.Communities.GroupMembershipTest do
  use Huddlz.DataCase

  alias Huddlz.Communities.Group
  alias Huddlz.Communities.GroupMember
  alias Huddlz.Accounts.User

  require Ash.Query

  describe "join_group/2" do
    setup do
      admin = user_fixture(%{role: :admin})
      verified_user = user_fixture(%{role: :verified})
      regular_user = user_fixture(%{role: :regular})

      public_group = group_fixture(admin, %{is_public: true})
      private_group = group_fixture(admin, %{is_public: false})

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
               |> Ash.Changeset.for_create(
                 :join_group,
                 %{
                   group_id: group.id,
                   user_id: user.id
                 },
                 actor: user
               )
               |> Ash.create()

      assert membership.user_id == user.id
      assert membership.group_id == group.id
      assert membership.role == :member
    end

    test "user cannot join private group", %{verified_user: user, private_group: group} do
      assert {:error, _} =
               GroupMember
               |> Ash.Changeset.for_create(
                 :join_group,
                 %{
                   group_id: group.id,
                   user_id: user.id
                 },
                 actor: user
               )
               |> Ash.create()
    end

    test "user cannot join for someone else", %{
      verified_user: user,
      regular_user: other_user,
      public_group: group
    } do
      assert {:error, _} =
               GroupMember
               |> Ash.Changeset.for_create(
                 :join_group,
                 %{
                   group_id: group.id,
                   user_id: other_user.id
                 },
                 actor: user
               )
               |> Ash.create()
    end
  end

  describe "leave_group/2" do
    setup do
      admin = user_fixture(%{role: :admin})
      verified_user = user_fixture(%{role: :verified})

      public_group = group_fixture(admin, %{is_public: true})

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

    test "owner can leave their own group (transfer ownership is out of scope)", %{
      admin: owner,
      public_group: group
    } do
      owner_membership =
        GroupMember
        |> Ash.Query.filter(group_id == ^group.id and user_id == ^owner.id)
        |> Ash.read_one!(authorize?: false)

      # Owners can leave - ownership transfer is a future feature
      assert :ok = Ash.destroy(owner_membership, action: :leave_group, actor: owner)

      # Verify owner was removed
      assert {:ok, nil} ==
               GroupMember
               |> Ash.Query.filter(group_id == ^group.id and user_id == ^owner.id)
               |> Ash.read_one(authorize?: false)
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
      admin = user_fixture(%{role: :admin})

      {:ok, group} =
        Group
        |> Ash.Changeset.for_create(
          :create_group,
          %{
            name: "Test Group",
            description: "Test",
            is_public: true,
            owner_id: admin.id
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

  defp user_fixture(attrs) do
    Ash.Seed.seed!(User, %{
      email: "test-#{:rand.uniform(100_000)}@example.com",
      display_name: "Test User",
      role: Map.get(attrs, :role, :regular)
    })
  end

  defp group_fixture(owner, attrs) do
    {:ok, group} =
      Group
      |> Ash.Changeset.for_create(
        :create_group,
        Map.merge(
          %{
            name: "Test Group #{:rand.uniform(100_000)}",
            description: "A test group",
            is_public: true,
            owner_id: owner.id
          },
          attrs
        ),
        actor: owner
      )
      |> Ash.create()

    group
  end
end
