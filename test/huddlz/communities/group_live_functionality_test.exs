defmodule Huddlz.Communities.GroupLiveFunctionalityTest do
  use Huddlz.DataCase, async: true

  import Huddlz.Generator

  alias Huddlz.Communities.Group
  require Ash.Query

  describe "group visibility and access" do
    setup do
      owner = generate(user(role: :verified))
      viewer = generate(user(role: :regular))

      public_group =
        generate(
          group(
            is_public: true,
            owner_id: owner.id,
            name: "Public Group",
            actor: owner
          )
        )

      private_group =
        generate(
          group(
            is_public: false,
            owner_id: owner.id,
            name: "Private Group",
            actor: owner
          )
        )

      %{
        owner: owner,
        viewer: viewer,
        public_group: public_group,
        private_group: private_group
      }
    end

    test "public groups are visible in public listing", %{public_group: group} do
      groups =
        Group
        |> Ash.Query.filter(is_public: true)
        |> Ash.read!()

      assert Enum.any?(groups, &(&1.id == group.id))
    end

    test "private groups are not visible in public listing", %{private_group: group} do
      groups =
        Group
        |> Ash.Query.filter(is_public: true)
        |> Ash.read!()

      refute Enum.any?(groups, &(&1.id == group.id))
    end

    test "can load owner relationship", %{public_group: group, owner: owner} do
      loaded_group =
        Group
        |> Ash.get!(group.id)
        |> Ash.load!(:owner)

      assert loaded_group.owner.id == owner.id
    end
  end

  describe "group creation validation" do
    setup do
      actor = generate(user(role: :verified))
      %{actor: actor}
    end

    test "requires name", %{actor: actor} do
      assert {:error, %Ash.Error.Invalid{errors: errors}} =
               Group
               |> Ash.Changeset.for_create(:create_group, %{
                 description: "Missing name",
                 is_public: true,
                 owner_id: actor.id
               })
               |> Ash.create(actor: actor)

      assert Enum.any?(errors, fn error ->
               error.field == :name
             end)
    end

    test "enforces minimum name length", %{actor: actor} do
      assert {:error, %Ash.Error.Invalid{errors: errors}} =
               Group
               |> Ash.Changeset.for_create(:create_group, %{
                 # Too short
                 name: "AB",
                 is_public: true,
                 owner_id: actor.id
               })
               |> Ash.create(actor: actor)

      assert Enum.any?(errors, fn error ->
               error.field == :name &&
                 (error.message =~ "greater than or equal" || to_string(error) =~ "at least 3")
             end)
    end

    test "enforces maximum name length", %{actor: actor} do
      long_name = String.duplicate("a", 101)

      assert {:error, %Ash.Error.Invalid{errors: errors}} =
               Group
               |> Ash.Changeset.for_create(:create_group, %{
                 name: long_name,
                 is_public: true,
                 owner_id: actor.id
               })
               |> Ash.create(actor: actor)

      assert Enum.any?(errors, fn error ->
               error.field == :name &&
                 (error.message =~ "less than or equal" || to_string(error) =~ "at most 100")
             end)
    end

    test "enforces unique group names", %{actor: actor} do
      # Create first group
      {:ok, _group1} =
        Group
        |> Ash.Changeset.for_create(:create_group, %{
          name: "Unique Name Test",
          is_public: true,
          owner_id: actor.id
        })
        |> Ash.create(actor: actor)

      # Try to create second group with same name
      assert {:error, %Ash.Error.Invalid{}} =
               Group
               |> Ash.Changeset.for_create(:create_group, %{
                 name: "Unique Name Test",
                 is_public: true,
                 owner_id: actor.id
               })
               |> Ash.create(actor: actor)
    end

    test "defaults is_public to true", %{actor: actor} do
      {:ok, group} =
        Group
        |> Ash.Changeset.for_create(:create_group, %{
          name: "Default Public Test",
          owner_id: actor.id
        })
        |> Ash.create(actor: actor)

      assert group.is_public == true
    end

    test "allows optional fields", %{actor: actor} do
      {:ok, group} =
        Group
        |> Ash.Changeset.for_create(:create_group, %{
          name: "Full Details Group",
          description: "A group with all details",
          location: "San Francisco, CA",
          image_url: "https://example.com/image.jpg",
          is_public: false,
          owner_id: actor.id
        })
        |> Ash.create(actor: actor)

      assert to_string(group.description) == "A group with all details"
      assert group.location == "San Francisco, CA"
      assert group.image_url == "https://example.com/image.jpg"
      assert group.is_public == false
    end
  end

  describe "group queries" do
    setup do
      owner1 = generate(user(role: :verified))
      owner2 = generate(user(role: :admin))

      groups = [
        generate(group(name: "Alpha Group", is_public: true, owner_id: owner1.id, actor: owner1)),
        generate(group(name: "Beta Group", is_public: true, owner_id: owner2.id, actor: owner2)),
        generate(
          group(name: "Gamma Group", is_public: false, owner_id: owner1.id, actor: owner1)
        ),
        generate(group(name: "Delta Group", is_public: true, owner_id: owner2.id, actor: owner2))
      ]

      %{groups: groups, owner1: owner1, owner2: owner2}
    end

    test "can filter by owner", %{owner1: owner1} do
      groups =
        Group
        |> Ash.Query.filter(owner_id: owner1.id)
        |> Ash.read!(authorize?: false)

      assert length(groups) == 2
      assert Enum.all?(groups, &(&1.owner_id == owner1.id))
    end

    test "can search by name", %{groups: [alpha | _]} do
      {:ok, groups} =
        Huddlz.Communities.search_groups("Alpha", actor: alpha.owner)

      assert length(groups) == 1
      assert hd(groups).id == alpha.id
    end

    test "search is case-insensitive", %{groups: [alpha | _]} do
      {:ok, groups} =
        Huddlz.Communities.search_groups("alpha", actor: alpha.owner)

      assert length(groups) == 1
      assert hd(groups).id == alpha.id
    end

    test "can get groups by owner", %{owner1: owner1} do
      {:ok, groups} =
        Huddlz.Communities.get_by_owner(owner1.id, actor: owner1)

      assert length(groups) == 2
      assert Enum.all?(groups, &(&1.owner_id == owner1.id))
    end
  end

  describe "update_details action" do
    setup do
      owner = generate(user(role: :verified))

      group =
        generate(
          group(
            name: "Original Name",
            description: "Original description",
            owner_id: owner.id,
            actor: owner
          )
        )

      %{owner: owner, group: group}
    end

    test "can update group details", %{owner: owner, group: group} do
      {:ok, updated} =
        group
        |> Ash.Changeset.for_update(:update_details, %{
          name: "Updated Name",
          description: "Updated description",
          location: "New Location"
        })
        |> Ash.update(actor: owner)

      assert to_string(updated.name) == "Updated Name"
      assert to_string(updated.description) == "Updated description"
      assert updated.location == "New Location"
    end

    test "maintains required validations on update", %{owner: owner, group: group} do
      assert {:error, %Ash.Error.Invalid{errors: errors}} =
               group
               |> Ash.Changeset.for_update(:update_details, %{name: ""})
               |> Ash.update(actor: owner)

      assert Enum.any?(errors, fn error ->
               error.field == :name
             end)
    end
  end
end
