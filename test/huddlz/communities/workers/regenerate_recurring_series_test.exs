defmodule Huddlz.Communities.Workers.RegenerateRecurringSeriesTest do
  use Huddlz.DataCase, async: true
  use Oban.Testing, repo: Huddlz.Repo

  import Ecto.Query

  alias Huddlz.Communities
  alias Huddlz.Communities.Huddl
  alias Huddlz.Communities.Workers.RegenerateRecurringSeries
  alias Huddlz.Notifications
  alias Huddlz.Storage

  # Creates a recurring huddl through the :create action. Pins the start to
  # "tomorrow" so the weekly cadence is deterministic: with repeat_until 22 days
  # out, exactly 2 future instances are generated (days +7 and +14).
  defp create_recurring(opts \\ []) do
    owner = generate(user(role: :user))
    group = generate(group(is_public: true, owner_id: owner.id, actor: owner))

    huddl =
      generate(
        huddl(
          Keyword.merge(
            [
              title: "Recurring",
              group_id: group.id,
              creator_id: owner.id,
              actor: owner,
              date: Date.add(Date.utc_today(), 1),
              is_recurring: true,
              frequency: "weekly",
              repeat_until: Date.add(Date.utc_today(), 22)
            ],
            opts
          )
        )
      )

    %{owner: owner, group: group, huddl: huddl}
  end

  # Counts via the visibility-free read so private instances are included too.
  defp future_instances(huddl) do
    Huddl
    |> Ash.Query.for_read(:siblings_in_series, %{
      huddl_template_id: huddl.huddl_template_id,
      starting_after: huddl.starts_at
    })
    |> Ash.read!(authorize?: false)
  end

  defp attach_cover_image(huddl, _owner) do
    source_file = "test/fixtures/test_image.jpg"
    storage_path = "/uploads/huddl_cover_images/#{huddl.id}/recurrence.jpg"
    thumbnail_path = "/uploads/huddl_cover_images/#{huddl.id}/recurrence_thumb.jpg"

    assert {:ok, ^storage_path} = Storage.put(source_file, storage_path, "image/jpeg")
    assert {:ok, ^thumbnail_path} = Storage.put(source_file, thumbnail_path, "image/jpeg")

    assert {:ok, image} =
             Huddlz.Communities.HuddlCoverImage
             |> Ash.Changeset.for_create(:create, %{
               filename: "recurrence.jpg",
               content_type: "image/jpeg",
               size_bytes: File.stat!(source_file).size,
               storage_path: storage_path,
               thumbnail_path: thumbnail_path,
               huddl_id: huddl.id
             })
             |> Ash.create(authorize?: false)

    image
  end

  test "creating a recurring huddl links the template inline and enqueues generation" do
    %{huddl: huddl} = create_recurring()

    # Template linked on the same insert — no re-entrant update needed.
    refute is_nil(huddl.huddl_template_id)

    # Fan-out is deferred: nothing generated until the queue runs.
    assert future_instances(huddl) == []
    assert_enqueued(worker: RegenerateRecurringSeries, args: %{huddl_id: huddl.id})
  end

  test "the create transaction assigns a pending cover image before generation is enqueued" do
    owner = generate(user(role: :user))
    group = generate(group(is_public: true, owner_id: owner.id, actor: owner))
    source_file = "test/fixtures/test_image.jpg"
    storage_path = "/uploads/huddl_cover_images/pending/#{Ecto.UUID.generate()}.jpg"
    thumbnail_path = "/uploads/huddl_cover_images/pending/#{Ecto.UUID.generate()}_thumb.jpg"

    assert {:ok, ^storage_path} = Storage.put(source_file, storage_path, "image/jpeg")
    assert {:ok, ^thumbnail_path} = Storage.put(source_file, thumbnail_path, "image/jpeg")

    assert {:ok, pending_image} =
             Communities.create_pending_huddl_cover_image(
               group.id,
               %{
                 filename: "pending.jpg",
                 content_type: "image/jpeg",
                 size_bytes: File.stat!(source_file).size,
                 storage_path: storage_path,
                 thumbnail_path: thumbnail_path
               },
               actor: owner
             )

    huddl =
      Huddl
      |> Ash.Changeset.new()
      |> Ash.Changeset.set_argument(:pending_image_id, pending_image.id)
      |> Ash.Changeset.for_create(
        :create,
        %{
          title: "Recurring with image",
          description: "Test",
          date: Date.add(Date.utc_today(), 1),
          start_time: ~T[14:00:00],
          duration_minutes: 60,
          event_type: :virtual,
          virtual_link: "https://meet.example.com/ordered",
          group_id: group.id,
          is_recurring: true,
          frequency: "weekly",
          repeat_until: Date.add(Date.utc_today(), 22)
        },
        actor: owner
      )
      |> Ash.create!()

    assert {:ok, source_image} =
             Communities.get_current_huddl_cover_image(huddl.id, authorize?: false)

    assert source_image.id == pending_image.id
    assert %{success: 1} = Oban.drain_queue(queue: :default)

    for occurrence <- future_instances(huddl) do
      assert {:ok, occurrence_image} =
               Communities.get_current_huddl_cover_image(occurrence.id, authorize?: false)

      assert occurrence_image.filename == "pending.jpg"
    end
  end

  test "draining the queue generates the future instances" do
    %{huddl: huddl} = create_recurring()

    assert %{success: 1} = Oban.drain_queue(queue: :default)
    assert length(future_instances(huddl)) == 2
  end

  test "weekly virtual huddlz generate every occurrence with the recurrence contract" do
    %{owner: owner, group: group, huddl: huddl} =
      create_recurring(
        event_type: :virtual,
        physical_location: nil,
        virtual_link: "https://meet.example.com/weekly",
        max_attendees: 24,
        is_private: true,
        thumbnail_url: "https://images.example.com/weekly.jpg"
      )

    source_image = attach_cover_image(huddl, owner)

    assert %{success: 1} = Oban.drain_queue(queue: :default)

    assert [first, second] = future_instances(huddl) |> Enum.sort_by(& &1.starts_at, DateTime)

    assert DateTime.diff(first.starts_at, huddl.starts_at, :day) == 7
    assert DateTime.diff(second.starts_at, huddl.starts_at, :day) == 14

    for occurrence <- [first, second] do
      assert occurrence.event_type == :virtual
      assert occurrence.virtual_link == "https://meet.example.com/weekly"
      assert occurrence.physical_location == nil
      assert occurrence.max_attendees == 24
      assert occurrence.is_private
      assert occurrence.thumbnail_url == "https://images.example.com/weekly.jpg"
      assert occurrence.creator_id == owner.id
      assert occurrence.group_id == group.id

      assert {:ok, occurrence_image} =
               Communities.get_current_huddl_cover_image(occurrence.id, authorize?: false)

      assert occurrence_image.filename == source_image.filename
      assert occurrence_image.content_type == source_image.content_type
      assert occurrence_image.size_bytes == source_image.size_bytes
      refute occurrence_image.storage_path == source_image.storage_path
      refute occurrence_image.thumbnail_path == source_image.thumbnail_path
      assert Storage.exists?(occurrence_image.storage_path)
      assert Storage.exists?(occurrence_image.thumbnail_path)
    end
  end

  test "weekly hybrid huddlz retain both locations for every occurrence" do
    %{huddl: huddl} =
      create_recurring(
        event_type: :hybrid,
        virtual_link: "https://meet.example.com/hybrid"
      )

    assert %{success: 1} = Oban.drain_queue(queue: :default)

    assert [first, second] = future_instances(huddl) |> Enum.sort_by(& &1.starts_at, DateTime)

    for occurrence <- [first, second] do
      assert occurrence.event_type == :hybrid
      assert occurrence.physical_location == "123 Main St, Anytown, USA"
      assert occurrence.virtual_link == "https://meet.example.com/hybrid"
    end
  end

  test "capacity-constrained recurring huddlz retain their attendance limit" do
    %{huddl: huddl} = create_recurring(max_attendees: 3)

    assert %{success: 1} = Oban.drain_queue(queue: :default)

    assert future_instances(huddl)
           |> Enum.all?(&(&1.max_attendees == 3))
  end

  test "re-running the job regenerates without duplicating" do
    %{owner: owner, huddl: huddl} = create_recurring()
    attach_cover_image(huddl, owner)

    assert %{success: 1} = Oban.drain_queue(queue: :default)
    first_generation = future_instances(huddl)
    assert length(first_generation) == 2

    old_image_paths =
      Enum.map(first_generation, fn occurrence ->
        assert {:ok, image} =
                 Communities.get_current_huddl_cover_image(occurrence.id, authorize?: false)

        image.storage_path
      end)

    assert :ok = perform_job(RegenerateRecurringSeries, %{huddl_id: huddl.id})

    second_generation = future_instances(huddl)
    assert length(second_generation) == 2

    refute Enum.any?(old_image_paths, &Storage.exists?/1)

    for occurrence <- second_generation do
      assert {:ok, image} =
               Communities.get_current_huddl_cover_image(occurrence.id, authorize?: false)

      assert Storage.exists?(image.storage_path)
    end
  end

  test "generated instances inherit the parent's coordinates without re-geocoding" do
    owner = generate(user(role: :user))
    group = generate(group(is_public: true, owner_id: owner.id, actor: owner))

    # provided_latitude/longitude are private args, set via set_argument rather
    # than the params map. With coordinates supplied the parent skips geocoding;
    # the default stub returns :not_found, so an instance that re-geocoded would
    # come back with nil coordinates instead of the parent's — proving the copy.
    parent =
      Huddl
      |> Ash.Changeset.new()
      |> Ash.Changeset.for_create(
        :create,
        %{
          title: "Recurring",
          description: "Test",
          date: Date.add(Date.utc_today(), 1),
          start_time: ~T[14:00:00],
          duration_minutes: 60,
          event_type: :in_person,
          group_location_id: address_book_location_id(group.id),
          group_id: group.id,
          is_recurring: true,
          frequency: "weekly",
          repeat_until: Date.add(Date.utc_today(), 22)
        },
        actor: owner
      )
      |> Ash.create!()

    assert parent.latitude == 29.9012
    assert %{success: 1} = Oban.drain_queue(queue: :default)

    instances = future_instances(parent)
    assert length(instances) == 2
    assert Enum.all?(instances, &(&1.latitude == 29.9012 and &1.longitude == -81.3124))
  end

  test "no-ops when the huddl was deleted before the job runs" do
    %{huddl: huddl} = create_recurring()
    Ash.destroy!(huddl, authorize?: false)

    assert :ok = perform_job(RegenerateRecurringSeries, %{huddl_id: huddl.id})
  end

  test "surfaces a final generation failure to the organizer" do
    %{owner: owner, huddl: huddl} =
      create_recurring(
        event_type: :virtual,
        physical_location: nil,
        virtual_link: "https://meet.example.com/failure"
      )

    Huddlz.Repo.update_all(
      from(h in "huddlz", where: h.id == type(^huddl.id, Ecto.UUID)),
      set: [virtual_link: nil]
    )

    job = %Oban.Job{
      args: %{"huddl_id" => huddl.id},
      attempt: 3,
      max_attempts: 3
    }

    assert_raise Ash.Error.Invalid, fn ->
      RegenerateRecurringSeries.perform(job)
    end

    assert {:ok, %{results: notifications}} =
             Notifications.list_for_user(actor: owner, page: [limit: 10])

    assert Enum.any?(notifications, fn notification ->
             notification.trigger == "recurring_huddl_generation_failed" and
               notification.source_url =~ huddl.id
           end)
  end
end
