defmodule Huddlz.Communities.GroupLocationTest do
  use Huddlz.DataCase, async: true

  alias Huddlz.Communities.GroupLocation

  describe "group_location creation" do
    test "owner can create a group location" do
      owner = generate(user(role: :user))
      group = generate(group(owner_id: owner.id, actor: owner))

      assert {:ok, location} =
               GroupLocation
               |> Ash.Changeset.for_create(:create, %{
                 name: "Community Center",
                 address: "100 Main St, Austin, TX",
                 latitude: 30.27,
                 longitude: -97.74,
                 group_id: group.id
               })
               |> Ash.create(actor: owner)

      assert location.name == "Community Center"
      assert location.address == "100 Main St, Austin, TX"
      assert location.latitude == 30.27
      assert location.longitude == -97.74
    end

    test "organizer can create a group location" do
      owner = generate(user(role: :user))
      organizer = generate(user(role: :user))
      group = generate(group(owner_id: owner.id, actor: owner))

      generate(
        group_member(group_id: group.id, user_id: organizer.id, role: :organizer, actor: owner)
      )

      assert {:ok, _location} =
               GroupLocation
               |> Ash.Changeset.for_create(:create, %{
                 name: "Park",
                 address: "200 Park Ave, Austin, TX",
                 latitude: 30.28,
                 longitude: -97.75,
                 group_id: group.id
               })
               |> Ash.create(actor: organizer)
    end

    test "regular member cannot create a group location" do
      owner = generate(user(role: :user))
      member = generate(user(role: :user))
      group = generate(group(owner_id: owner.id, actor: owner))
      generate(group_member(group_id: group.id, user_id: member.id, role: :member, actor: owner))

      assert {:error, %Ash.Error.Forbidden{}} =
               GroupLocation
               |> Ash.Changeset.for_create(:create, %{
                 name: "Forbidden",
                 address: "999 No Way, Austin, TX",
                 latitude: 30.27,
                 longitude: -97.74,
                 group_id: group.id
               })
               |> Ash.create(actor: member)
    end

    test "address is required" do
      owner = generate(user(role: :user))
      group = generate(group(owner_id: owner.id, actor: owner))

      assert {:error, _} =
               GroupLocation
               |> Ash.Changeset.for_create(:create, %{
                 name: "No Address",
                 latitude: 30.27,
                 longitude: -97.74,
                 group_id: group.id
               })
               |> Ash.create(actor: owner)
    end

    test "latitude and longitude are required" do
      owner = generate(user(role: :user))
      group = generate(group(owner_id: owner.id, actor: owner))

      assert {:error, _} =
               GroupLocation
               |> Ash.Changeset.for_create(:create, %{
                 name: "No Coords",
                 address: "100 Main St, Austin, TX",
                 group_id: group.id
               })
               |> Ash.create(actor: owner)
    end

    test "name is optional" do
      owner = generate(user(role: :user))
      group = generate(group(owner_id: owner.id, actor: owner))

      assert {:ok, location} =
               GroupLocation
               |> Ash.Changeset.for_create(:create, %{
                 address: "100 Main St, Austin, TX",
                 latitude: 30.27,
                 longitude: -97.74,
                 group_id: group.id
               })
               |> Ash.create(actor: owner)

      assert is_nil(location.name)
    end

    test "duplicate names within same group are rejected" do
      owner = generate(user(role: :user))
      group = generate(group(owner_id: owner.id, actor: owner))

      {:ok, _} =
        GroupLocation
        |> Ash.Changeset.for_create(:create, %{
          name: "HQ",
          address: "100 Main St, Austin, TX",
          latitude: 30.27,
          longitude: -97.74,
          group_id: group.id
        })
        |> Ash.create(actor: owner)

      assert {:error, _} =
               GroupLocation
               |> Ash.Changeset.for_create(:create, %{
                 name: "HQ",
                 address: "200 Other St, Austin, TX",
                 latitude: 30.28,
                 longitude: -97.75,
                 group_id: group.id
               })
               |> Ash.create(actor: owner)
    end

    test "same name across different groups is allowed" do
      owner = generate(user(role: :user))
      group1 = generate(group(owner_id: owner.id, actor: owner))
      group2 = generate(group(owner_id: owner.id, actor: owner))

      {:ok, _} =
        GroupLocation
        |> Ash.Changeset.for_create(:create, %{
          name: "HQ",
          address: "100 Main St, Austin, TX",
          latitude: 30.27,
          longitude: -97.74,
          group_id: group1.id
        })
        |> Ash.create(actor: owner)

      assert {:ok, _} =
               GroupLocation
               |> Ash.Changeset.for_create(:create, %{
                 name: "HQ",
                 address: "200 Other St, Austin, TX",
                 latitude: 30.28,
                 longitude: -97.75,
                 group_id: group2.id
               })
               |> Ash.create(actor: owner)
    end
  end

  describe "group_location read" do
    test "by_group returns locations for the given group" do
      owner = generate(user(role: :user))
      group = generate(group(owner_id: owner.id, actor: owner))
      other_group = generate(group(owner_id: owner.id, actor: owner))

      generate(group_location(group_id: group.id, name: "Location A", actor: owner))
      generate(group_location(group_id: other_group.id, name: "Other Location", actor: owner))

      {:ok, locations} =
        GroupLocation
        |> Ash.Query.for_read(:by_group, %{group_id: group.id})
        |> Ash.read(actor: owner)

      assert length(locations) == 1
      assert hd(locations).name == "Location A"
    end

    test "by_group sorts by name ascending" do
      owner = generate(user(role: :user))
      group = generate(group(owner_id: owner.id, actor: owner))

      generate(group_location(group_id: group.id, name: "Zebra Venue", actor: owner))
      generate(group_location(group_id: group.id, name: "Alpha Hall", actor: owner))
      generate(group_location(group_id: group.id, name: "Middle Place", actor: owner))

      {:ok, locations} =
        GroupLocation
        |> Ash.Query.for_read(:by_group, %{group_id: group.id})
        |> Ash.read(actor: owner)

      names = Enum.map(locations, & &1.name)
      assert names == ["Alpha Hall", "Middle Place", "Zebra Venue"]
    end

    test "anyone can read group locations" do
      owner = generate(user(role: :user))
      random_user = generate(user(role: :user))
      group = generate(group(owner_id: owner.id, actor: owner))
      generate(group_location(group_id: group.id, name: "Public Location", actor: owner))

      {:ok, locations} =
        GroupLocation
        |> Ash.Query.for_read(:by_group, %{group_id: group.id})
        |> Ash.read(actor: random_user)

      assert length(locations) == 1
    end
  end

  describe "group_location update" do
    test "owner can rename a location" do
      owner = generate(user(role: :user))
      group = generate(group(owner_id: owner.id, actor: owner))
      location = generate(group_location(group_id: group.id, name: "Old Name", actor: owner))

      assert {:ok, updated} =
               location
               |> Ash.Changeset.for_update(:update, %{name: "New Name"})
               |> Ash.update(actor: owner)

      assert updated.name == "New Name"
    end

    test "organizer can rename a location" do
      owner = generate(user(role: :user))
      organizer = generate(user(role: :user))
      group = generate(group(owner_id: owner.id, actor: owner))

      generate(
        group_member(group_id: group.id, user_id: organizer.id, role: :organizer, actor: owner)
      )

      location = generate(group_location(group_id: group.id, name: "Old Name", actor: owner))

      assert {:ok, updated} =
               location
               |> Ash.Changeset.for_update(:update, %{name: "Updated by Organizer"})
               |> Ash.update(actor: organizer)

      assert updated.name == "Updated by Organizer"
    end

    test "regular member cannot update" do
      owner = generate(user(role: :user))
      member = generate(user(role: :user))
      group = generate(group(owner_id: owner.id, actor: owner))
      generate(group_member(group_id: group.id, user_id: member.id, role: :member, actor: owner))
      location = generate(group_location(group_id: group.id, name: "Immutable", actor: owner))

      assert {:error, %Ash.Error.Forbidden{}} =
               location
               |> Ash.Changeset.for_update(:update, %{name: "Hacked"})
               |> Ash.update(actor: member)
    end
  end

  describe "group_location destroy" do
    test "owner can delete a location" do
      owner = generate(user(role: :user))
      group = generate(group(owner_id: owner.id, actor: owner))
      location = generate(group_location(group_id: group.id, actor: owner))

      assert :ok = Ash.destroy(location, actor: owner)
    end

    test "organizer can delete a location" do
      owner = generate(user(role: :user))
      organizer = generate(user(role: :user))
      group = generate(group(owner_id: owner.id, actor: owner))

      generate(
        group_member(group_id: group.id, user_id: organizer.id, role: :organizer, actor: owner)
      )

      location = generate(group_location(group_id: group.id, actor: owner))

      assert :ok = Ash.destroy(location, actor: organizer)
    end

    test "regular member cannot delete" do
      owner = generate(user(role: :user))
      member = generate(user(role: :user))
      group = generate(group(owner_id: owner.id, actor: owner))
      generate(group_member(group_id: group.id, user_id: member.id, role: :member, actor: owner))
      location = generate(group_location(group_id: group.id, actor: owner))

      assert {:error, %Ash.Error.Forbidden{}} = Ash.destroy(location, actor: member)
    end
  end

  describe "attribute constraints" do
    test "rejects name over 200 characters" do
      owner = generate(user(role: :user))
      group = generate(group(owner_id: owner.id, actor: owner))
      long_name = String.duplicate("a", 201)

      assert {:error, _} =
               GroupLocation
               |> Ash.Changeset.for_create(:create, %{
                 name: long_name,
                 address: "100 Main St, Austin, TX",
                 latitude: 30.27,
                 longitude: -97.74,
                 group_id: group.id
               })
               |> Ash.create(actor: owner)
    end

    test "rejects address over 500 characters" do
      owner = generate(user(role: :user))
      group = generate(group(owner_id: owner.id, actor: owner))
      long_address = String.duplicate("a", 501)

      assert {:error, _} =
               GroupLocation
               |> Ash.Changeset.for_create(:create, %{
                 name: "Test",
                 address: long_address,
                 latitude: 30.27,
                 longitude: -97.74,
                 group_id: group.id
               })
               |> Ash.create(actor: owner)
    end

    test "rejects latitude out of range" do
      owner = generate(user(role: :user))
      group = generate(group(owner_id: owner.id, actor: owner))

      assert {:error, _} =
               GroupLocation
               |> Ash.Changeset.for_create(:create, %{
                 address: "100 Main St, Austin, TX",
                 latitude: 91.0,
                 longitude: -97.74,
                 group_id: group.id
               })
               |> Ash.create(actor: owner)
    end

    test "rejects longitude out of range" do
      owner = generate(user(role: :user))
      group = generate(group(owner_id: owner.id, actor: owner))

      assert {:error, _} =
               GroupLocation
               |> Ash.Changeset.for_create(:create, %{
                 address: "100 Main St, Austin, TX",
                 latitude: 30.27,
                 longitude: -181.0,
                 group_id: group.id
               })
               |> Ash.create(actor: owner)
    end
  end
end
