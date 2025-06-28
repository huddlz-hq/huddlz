defmodule Huddlz.Communities.GroupPoliciesTest do
  use Huddlz.DataCase, async: true

  alias Huddlz.Accounts.User
  alias Huddlz.Communities.Group

  setup do
    # Create test users
    owner =
      Ash.Seed.seed!(User, %{
        email: "owner@example.com",
        display_name: "Owner User",
        role: :user
      })

    verified_user =
      Ash.Seed.seed!(User, %{
        email: "verified@example.com",
        display_name: "Verified User",
        role: :user
      })

    regular_user =
      Ash.Seed.seed!(User, %{
        email: "regular@example.com",
        display_name: "Regular User",
        role: :user
      })

    # Create a test group
    {:ok, group} =
      Group
      |> Ash.Changeset.for_create(:create_group, %{
        name: "Test Group",
        description: "A test group",
        location: "Test Location",
        is_public: true,
        owner_id: owner.id
      })
      |> Ash.create(actor: owner)

    %{
      owner: owner,
      verified_user: verified_user,
      regular_user: regular_user,
      group: group
    }
  end

  describe "get_by_slug policy" do
    test "anyone can get a group by slug - anonymous user", %{group: group} do
      assert {:ok, fetched_group} =
               Huddlz.Communities.get_by_slug(group.slug, actor: nil)

      assert fetched_group.id == group.id
    end

    test "anyone can get a group by slug - regular user", %{group: group, regular_user: user} do
      assert {:ok, fetched_group} =
               Huddlz.Communities.get_by_slug(group.slug, actor: user)

      assert fetched_group.id == group.id
    end

    test "anyone can get a group by slug - verified user", %{group: group, verified_user: user} do
      assert {:ok, fetched_group} =
               Huddlz.Communities.get_by_slug(group.slug, actor: user)

      assert fetched_group.id == group.id
    end

    test "anyone can get a group by slug - owner", %{group: group, owner: owner} do
      assert {:ok, fetched_group} =
               Huddlz.Communities.get_by_slug(group.slug, actor: owner)

      assert fetched_group.id == group.id
    end

    test "returns error for non-existent slug" do
      assert {:error, %Ash.Error.Invalid{}} =
               Huddlz.Communities.get_by_slug("non-existent-slug", actor: nil)
    end
  end

  describe "update_details policy" do
    test "owner can update group details", %{group: group, owner: owner} do
      assert {:ok, updated_group} =
               group
               |> Ash.Changeset.for_update(:update_details, %{name: "Updated Name"})
               |> Ash.update(actor: owner)

      assert to_string(updated_group.name) == "Updated Name"
    end

    test "non-owner cannot update group details", %{group: group, verified_user: user} do
      assert {:error, %Ash.Error.Forbidden{}} =
               group
               |> Ash.Changeset.for_update(:update_details, %{name: "Updated Name"})
               |> Ash.update(actor: user)
    end

    test "user cannot update group details", %{group: group, regular_user: user} do
      assert {:error, %Ash.Error.Forbidden{}} =
               group
               |> Ash.Changeset.for_update(:update_details, %{name: "Updated Name"})
               |> Ash.update(actor: user)
    end
  end

  describe "create_group policy" do
    test "user can create group", %{verified_user: user} do
      assert {:ok, group} =
               Group
               |> Ash.Changeset.for_create(:create_group, %{
                 name: "New Group",
                 description: "Test group",
                 location: "Test Location",
                 is_public: true,
                 owner_id: user.id
               })
               |> Ash.create(actor: user)

      assert to_string(group.name) == "New Group"
      assert group.owner_id == user.id
    end

    test "admin can create group" do
      admin =
        Ash.Seed.seed!(User, %{
          email: "admin-policy@example.com",
          display_name: "Admin User",
          role: :admin
        })

      assert {:ok, group} =
               Group
               |> Ash.Changeset.for_create(:create_group, %{
                 name: "Admin Group",
                 description: "Test group",
                 location: "Test Location",
                 is_public: true,
                 owner_id: admin.id
               })
               |> Ash.create(actor: admin)

      assert to_string(group.name) == "Admin Group"
    end

    test "regular user can create group", %{regular_user: user} do
      assert {:ok, group} =
               Group
               |> Ash.Changeset.for_create(:create_group, %{
                 name: "New Group",
                 description: "Test group",
                 location: "Test Location",
                 is_public: true,
                 owner_id: user.id
               })
               |> Ash.create(actor: user)

      assert to_string(group.name) == "New Group"
      assert group.owner_id == user.id
    end
  end
end
