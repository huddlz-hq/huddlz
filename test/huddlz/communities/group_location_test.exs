defmodule Huddlz.Communities.GroupLocationTest do
  use Huddlz.DataCase, async: true

  require Ash.Query

  alias Ecto.Adapters.SQL.Sandbox
  alias Huddlz.Communities
  alias Huddlz.Communities.GroupLocation
  alias Huddlz.Communities.Huddl
  alias Huddlz.Communities.Huddl.RecurrenceHelper
  alias Huddlz.Communities.HuddlTemplate

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

    test "anonymous user can read a public group's locations" do
      owner = generate(user(role: :user))
      group = generate(group(owner_id: owner.id, is_public: true, actor: owner))
      generate(group_location(group_id: group.id, name: "Public Location", actor: owner))

      {:ok, locations} =
        GroupLocation
        |> Ash.Query.for_read(:by_group, %{group_id: group.id})
        |> Ash.read(actor: nil)

      assert length(locations) == 1
    end

    test "non-member cannot read a private group's locations" do
      owner = generate(user(role: :user))
      outsider = generate(user(role: :user))
      group = generate(group(owner_id: owner.id, is_public: false, actor: owner))
      generate(group_location(group_id: group.id, name: "Secret HQ", actor: owner))

      {:ok, locations} =
        GroupLocation
        |> Ash.Query.for_read(:by_group, %{group_id: group.id})
        |> Ash.read(actor: outsider)

      assert locations == []
    end

    test "anonymous user cannot read a private group's locations" do
      owner = generate(user(role: :user))
      group = generate(group(owner_id: owner.id, is_public: false, actor: owner))
      generate(group_location(group_id: group.id, name: "Secret HQ", actor: owner))

      {:ok, locations} =
        GroupLocation
        |> Ash.Query.for_read(:by_group, %{group_id: group.id})
        |> Ash.read(actor: nil)

      assert locations == []
    end

    test "member can read a private group's locations" do
      owner = generate(user(role: :user))
      member = generate(user(role: :user))
      group = generate(group(owner_id: owner.id, is_public: false, actor: owner))
      generate(group_member(group_id: group.id, user_id: member.id, role: :member, actor: owner))
      generate(group_location(group_id: group.id, name: "Members Only", actor: owner))

      {:ok, locations} =
        GroupLocation
        |> Ash.Query.for_read(:by_group, %{group_id: group.id})
        |> Ash.read(actor: member)

      assert length(locations) == 1
      assert hd(locations).name == "Members Only"
    end

    test "owner can read their private group's locations" do
      owner = generate(user(role: :user))
      group = generate(group(owner_id: owner.id, is_public: false, actor: owner))
      generate(group_location(group_id: group.id, name: "HQ", actor: owner))

      {:ok, locations} =
        GroupLocation
        |> Ash.Query.for_read(:by_group, %{group_id: group.id})
        |> Ash.read(actor: owner)

      assert length(locations) == 1
    end
  end

  describe "group_location update" do
    test "rejects a blank location name" do
      owner = generate(user(role: :user))
      group = generate(group(owner_id: owner.id, actor: owner))
      location = generate(group_location(group_id: group.id, name: "Original Name", actor: owner))

      assert {:error, error} =
               location
               |> Ash.Changeset.for_update(:update, %{name: ""})
               |> Ash.update(actor: owner)

      assert Enum.any?(error.errors, fn error ->
               error.field == :name && error.message == "Name is required"
             end)
    end

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

      assert :ok = Communities.delete_group_location(location, actor: owner)
    end

    test "organizer can delete a location" do
      owner = generate(user(role: :user))
      organizer = generate(user(role: :user))
      group = generate(group(owner_id: owner.id, actor: owner))

      generate(
        group_member(group_id: group.id, user_id: organizer.id, role: :organizer, actor: owner)
      )

      location = generate(group_location(group_id: group.id, actor: owner))

      assert :ok = Communities.delete_group_location(location, actor: organizer)
    end

    test "regular member cannot delete" do
      owner = generate(user(role: :user))
      member = generate(user(role: :user))
      group = generate(group(owner_id: owner.id, actor: owner))
      generate(group_member(group_id: group.id, user_id: member.id, role: :member, actor: owner))
      location = generate(group_location(group_id: group.id, actor: owner))

      assert {:error, %Ash.Error.Forbidden{}} =
               Communities.delete_group_location(location, actor: member)
    end

    test "cannot delete a location used by an upcoming huddl" do
      owner = generate(user(role: :user))
      group = generate(group(owner_id: owner.id, actor: owner))

      location =
        generate(
          group_location(
            group_id: group.id,
            name: "Tomorrow's Venue",
            address: "100 Future St, Austin, TX",
            actor: owner
          )
        )

      generate(
        huddl_at_location(
          group_id: group.id,
          creator_id: owner.id,
          group_location_id: location.id,
          physical_location: location.address,
          latitude: location.latitude,
          longitude: location.longitude,
          starts_at: DateTime.add(DateTime.utc_now(), 1, :day),
          ends_at: DateTime.add(DateTime.utc_now(), 1, :day)
        )
      )

      assert {:error, error} = Communities.delete_group_location(location, actor: owner)
      assert Exception.message(error) =~ "used by 1 current or upcoming huddl"

      assert {:ok, [_location]} =
               Communities.list_group_locations(group.id, actor: owner)
    end

    test "deleting a location used only by a past huddl preserves its venue address" do
      owner = generate(user(role: :user))
      group = generate(group(owner_id: owner.id, actor: owner))

      location =
        generate(
          group_location(
            group_id: group.id,
            name: "Historic Hall",
            address: "200 History Ln, Austin, TX",
            actor: owner
          )
        )

      huddl =
        generate(
          past_huddl(
            group_id: group.id,
            creator_id: owner.id,
            group_location_id: location.id,
            physical_location: location.address,
            latitude: location.latitude,
            longitude: location.longitude
          )
        )

      assert :ok = Communities.delete_group_location(location, actor: owner)

      reloaded_huddl =
        Huddlz.Communities.Huddl
        |> Ash.Query.filter(id == ^huddl.id)
        |> Ash.read_one!(authorize?: false)

      assert reloaded_huddl.physical_location == "200 History Ln, Austin, TX"
      assert is_nil(reloaded_huddl.group_location_id)
      assert {:ok, []} = Communities.list_group_locations(group.id, actor: owner)
    end

    test "a matching address does not conflate distinct saved locations" do
      owner = generate(user(role: :user))
      group = generate(group(owner_id: owner.id, actor: owner))

      referenced_location =
        generate(
          group_location(
            group_id: group.id,
            name: "Referenced",
            address: "300 Shared St, Austin, TX",
            actor: owner
          )
        )

      disposable_location =
        generate(
          group_location(
            group_id: group.id,
            name: "Disposable",
            address: referenced_location.address,
            actor: owner
          )
        )

      generate(
        huddl_at_location(
          group_id: group.id,
          creator_id: owner.id,
          group_location_id: referenced_location.id,
          physical_location: referenced_location.address,
          starts_at: DateTime.add(DateTime.utc_now(), 1, :day),
          ends_at: DateTime.add(DateTime.utc_now(), 1, :day)
        )
      )

      assert :ok = Communities.delete_group_location(disposable_location, actor: owner)
      assert {:ok, [remaining]} = Communities.list_group_locations(group.id, actor: owner)
      assert remaining.id == referenced_location.id
    end

    test "a recurring series blocks deletion through its copied saved-location reference" do
      owner = generate(user(role: :user))
      group = generate(group(owner_id: owner.id, actor: owner))

      location =
        generate(
          group_location(
            group_id: group.id,
            name: "Series Venue",
            actor: owner
          )
        )

      template =
        HuddlTemplate
        |> Ash.Changeset.for_create(:create, %{
          interval: 1,
          unit: :week,
          repeat_until: DateTime.add(DateTime.utc_now(), 10, :day),
          starts_at_local: DateTime.utc_now() |> DateTime.add(1, :day) |> DateTime.to_naive(),
          ends_at_local:
            DateTime.utc_now()
            |> DateTime.add(1, :day)
            |> DateTime.add(1, :hour)
            |> DateTime.to_naive(),
          time_zone: "Etc/UTC"
        })
        |> Ash.create!(authorize?: false)

      starts_at = DateTime.add(DateTime.utc_now(), 1, :day)

      source =
        generate(
          huddl_at_location(
            group_id: group.id,
            creator_id: owner.id,
            group_location_id: location.id,
            huddl_template_id: template.id,
            physical_location: location.address,
            starts_at: starts_at,
            ends_at: DateTime.add(starts_at, 1, :hour)
          )
        )

      assert :ok = RecurrenceHelper.generate_huddlz_from_template(template, source)

      assert [_generated] =
               Huddl
               |> Ash.Query.filter(id != ^source.id and huddl_template_id == ^template.id)
               |> Ash.read!(authorize?: false)

      assert {:error, error} = Communities.delete_group_location(location, actor: owner)
      assert Exception.message(error) =~ "used by 2 current or upcoming huddlz"
    end

    test "an in-progress huddl is described as current rather than upcoming" do
      owner = generate(user(role: :user))
      group = generate(group(owner_id: owner.id, actor: owner))
      location = generate(group_location(group_id: group.id, actor: owner))
      now = DateTime.utc_now()

      generate(
        huddl_at_location(
          group_id: group.id,
          creator_id: owner.id,
          group_location_id: location.id,
          physical_location: location.address,
          starts_at: DateTime.add(now, -1, :hour),
          ends_at: DateTime.add(now, 1, :hour)
        )
      )

      assert {:error, error} = Communities.delete_group_location(location, actor: owner)
      assert Exception.message(error) =~ "1 current or upcoming huddl"
    end

    test "repeated deletion returns an idempotent result" do
      owner = generate(user(role: :user))
      group = generate(group(owner_id: owner.id, actor: owner))
      location = generate(group_location(group_id: group.id, actor: owner))

      assert :ok = Communities.delete_group_location(location, actor: owner)

      assert {:ok, :already_deleted} =
               Communities.delete_group_location(location, actor: owner)

      assert {:ok, []} = Communities.list_group_locations(group.id, actor: owner)
    end

    test "concurrent deletion attempts both return useful results" do
      owner = generate(user(role: :user))
      group = generate(group(owner_id: owner.id, actor: owner))
      location = generate(group_location(group_id: group.id, actor: owner))
      test_process = self()

      tasks =
        Enum.map(1..2, fn _attempt ->
          Task.async(fn ->
            send(test_process, {:delete_ready, self()})

            receive do
              :delete_location ->
                Communities.delete_group_location(location, actor: owner)
            end
          end)
        end)

      Enum.each(tasks, fn task ->
        task_pid = task.pid
        Sandbox.allow(Huddlz.Repo, test_process, task_pid)
        assert_receive {:delete_ready, ^task_pid}
      end)

      Enum.each(tasks, &send(&1.pid, :delete_location))

      assert tasks
             |> Task.await_many()
             |> Enum.sort() == [:ok, {:ok, :already_deleted}]
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
