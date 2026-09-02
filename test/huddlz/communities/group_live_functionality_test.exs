defmodule Huddlz.Communities.GroupLiveFunctionalityTest do
  use Huddlz.DataCase, async: true

  import Huddlz.Generator

  alias Huddlz.Communities.Group
  alias Huddlz.Repo
  require Ash.Query

  describe "group visibility and access" do
    setup do
      owner = generate(user(role: :user))
      viewer = generate(user(role: :user))

      public_group =
        generate(
          group(
            is_public: true,
            name: "Public Group",
            actor: owner
          )
        )

      private_group =
        generate(
          group(
            is_public: false,
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
      actor = generate(user(role: :user))
      %{actor: actor}
    end

    test "requires name", %{actor: actor} do
      assert {:error, %Ash.Error.Invalid{errors: errors}} =
               Group
               |> Ash.Changeset.for_create(:create_group, %{
                 description: "Missing name",
                 location: "Test Location",
                 is_public: true
               })
               |> Ash.create(actor: actor)

      assert Enum.any?(errors, fn error ->
               error.field == :name
             end)
    end

    test "requires a location", %{actor: actor} do
      assert {:error, %Ash.Error.Invalid{errors: errors}} =
               Group
               |> Ash.Changeset.for_create(:create_group, %{
                 name: "Missing Location",
                 is_public: true
               })
               |> Ash.create(actor: actor)

      assert Enum.any?(errors, fn error ->
               error.field == :location && error.message == "is required"
             end)
    end

    test "derives the time zone from selected coordinates and rejects submitted overrides", %{
      actor: actor
    } do
      changeset =
        Group
        |> Ash.Changeset.new()
        |> Ash.Changeset.set_argument(:provided_latitude, 30.27)
        |> Ash.Changeset.set_argument(:provided_longitude, -97.74)

      assert {:ok, group} =
               changeset
               |> Ash.Changeset.for_create(:create_group, %{
                 name: "Resolved Zone Group",
                 location: "Austin, TX",
                 is_public: true
               })
               |> Ash.create(actor: actor)

      assert group.time_zone == "America/Chicago"

      assert {:error, error} =
               changeset
               |> Ash.Changeset.for_create(:create_group, %{
                 name: "Submitted Zone Group",
                 location: "Austin, TX",
                 time_zone: "America/Los_Angeles",
                 is_public: true
               })
               |> Ash.create(actor: actor)

      assert Exception.message(error) =~ "time_zone"
    end

    test "the database enforces locations for new groups without validating legacy rows" do
      assert %{rows: [[false, definition]]} =
               Repo.query!("""
               SELECT convalidated, pg_get_constraintdef(oid)
               FROM pg_constraint
               WHERE conname = 'groups_location_required_for_new_records'
               """)

      assert definition =~ "location IS NOT NULL"
      assert definition =~ "btrim(location) <> ''"
    end

    test "enforces minimum name length", %{actor: actor} do
      assert {:error, %Ash.Error.Invalid{errors: errors}} =
               Group
               |> Ash.Changeset.for_create(:create_group, %{
                 # Too short
                 name: "AB",
                 location: "Test Location",
                 is_public: true
               })
               |> Ash.create(actor: actor)

      assert Enum.any?(errors, fn error ->
               error.field == :name &&
                 error.message == "Must be between 3 and 100 characters"
             end)
    end

    test "enforces maximum name length", %{actor: actor} do
      long_name = String.duplicate("a", 101)

      assert {:error, %Ash.Error.Invalid{errors: errors}} =
               Group
               |> Ash.Changeset.for_create(:create_group, %{
                 name: long_name,
                 location: "Test Location",
                 is_public: true
               })
               |> Ash.create(actor: actor)

      assert Enum.any?(errors, fn error ->
               error.field == :name &&
                 error.message == "Must be between 3 and 100 characters"
             end)
    end

    test "enforces unique group names", %{actor: actor} do
      # Create first group
      {:ok, _group1} =
        create_group_changeset(actor, %{
          name: "Unique Name Test",
          location: "Test Location",
          is_public: true
        })
        |> Ash.create()

      # Try to create second group with same name
      assert {:error, %Ash.Error.Invalid{}} =
               create_group_changeset(actor, %{
                 name: "Unique Name Test",
                 location: "Test Location",
                 is_public: true
               })
               |> Ash.create()
    end

    test "defaults is_public to true", %{actor: actor} do
      {:ok, group} =
        create_group_changeset(actor, %{
          name: "Default Public Test",
          location: "Test Location"
        })
        |> Ash.create()

      assert group.is_public == true
    end

    test "allows optional fields", %{actor: actor} do
      {:ok, group} =
        create_group_changeset(actor, %{
          name: "Full Details Group",
          description: "A group with all details",
          location: "San Francisco, CA",
          is_public: false
        })
        |> Ash.create()

      assert to_string(group.description) == "A group with all details"
      assert group.location == "San Francisco, CA"
      assert group.is_public == false
    end
  end

  describe "group queries" do
    setup do
      owner1 = generate(user(role: :user))
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

    test "can search by name", %{groups: [alpha | _], owner1: owner1} do
      {:ok, groups} =
        Huddlz.Communities.search_groups("Alpha", actor: owner1)

      assert length(groups) == 1
      assert hd(groups).id == alpha.id
    end

    test "search is case-insensitive", %{groups: [alpha | _], owner1: owner1} do
      {:ok, groups} =
        Huddlz.Communities.search_groups("alpha", actor: owner1)

      assert length(groups) == 1
      assert hd(groups).id == alpha.id
    end

    test "can get groups owned by the current actor", %{owner1: owner1} do
      {:ok, groups} = Huddlz.Communities.get_by_owner(actor: owner1)

      assert length(groups) == 2
      assert Enum.all?(groups, &(&1.owner_id == owner1.id))
    end
  end

  describe "update_details action" do
    setup do
      owner = generate(user(role: :user))

      group =
        generate(
          group(
            name: "Original Name",
            description: "Original description",
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
          description: "Updated description"
        })
        |> Ash.update(actor: owner)

      assert to_string(updated.name) == "Updated Name"
      assert to_string(updated.description) == "Updated description"
      assert updated.location == group.location
    end

    test "derives a changed Group time zone from the new location", %{
      owner: owner,
      group: group
    } do
      changeset =
        group
        |> Ash.Changeset.new()
        |> Ash.Changeset.set_argument(:provided_latitude, 39.74)
        |> Ash.Changeset.set_argument(:provided_longitude, -104.99)

      assert {:ok, updated} =
               changeset
               |> Ash.Changeset.for_update(:update_details, %{
                 location: "Denver, CO"
               })
               |> Ash.update(actor: owner)

      assert updated.location == "Denver, CO"
      assert updated.time_zone == "America/Denver"

      assert {:error, error} =
               updated
               |> Ash.Changeset.for_update(:update_details, %{
                 time_zone: "America/Los_Angeles"
               })
               |> Ash.update(actor: owner)

      assert Exception.message(error) =~ "time_zone"
    end

    test "rejects a changed location whose time zone cannot be resolved", %{
      owner: owner,
      group: group
    } do
      Mox.stub(Huddlz.MockGeocoding, :geocode, fn _location -> {:error, :not_found} end)

      assert {:error, error} =
               group
               |> Ash.Changeset.for_update(:update_details, %{location: "Unresolvable Place"})
               |> Ash.update(actor: owner)

      assert Exception.message(error) =~
               "time zone could not be resolved for this location"

      unchanged = Ash.get!(Group, group.id, authorize?: false)
      assert unchanged.location == group.location
      assert unchanged.time_zone == group.time_zone
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

  defp create_group_changeset(actor, attrs) do
    Group
    |> Ash.Changeset.new()
    |> Ash.Changeset.set_argument(:provided_latitude, 29.89)
    |> Ash.Changeset.set_argument(:provided_longitude, -81.31)
    |> Ash.Changeset.for_create(:create_group, attrs, actor: actor)
  end
end
