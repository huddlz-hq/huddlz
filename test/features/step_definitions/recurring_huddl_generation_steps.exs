defmodule RecurringHuddlGenerationSteps do
  use Cucumber.StepDefinition

  import Ecto.Query
  import ExUnit.Assertions
  import Huddlz.Generator

  alias Huddlz.Communities
  alias Huddlz.Communities.Huddl
  alias Huddlz.Communities.HuddlImage
  alias Huddlz.Communities.Workers.RegenerateRecurringSeries
  alias Huddlz.Notifications
  alias Huddlz.Storage

  step "a weekly recurring virtual huddl with a cover image", context do
    context
    |> create_recurring_huddl(
      event_type: :virtual,
      physical_location: nil,
      virtual_link: "https://meet.example.com/weekly",
      is_private: true,
      max_attendees: 24
    )
    |> attach_cover_image()
  end

  step "a weekly recurring hybrid huddl", context do
    create_recurring_huddl(context,
      event_type: :hybrid,
      physical_location: "456 Congress Ave",
      virtual_link: "https://meet.example.com/hybrid"
    )
  end

  step "a weekly recurring huddl with a capacity of {int}",
       %{args: [capacity]} = context do
    create_recurring_huddl(context, max_attendees: capacity)
  end

  step "a weekly recurring huddl", context do
    create_recurring_huddl(context)
  end

  step "a weekly recurring virtual huddl that cannot generate future occurrences", context do
    context =
      create_recurring_huddl(context,
        event_type: :virtual,
        physical_location: nil,
        virtual_link: "https://meet.example.com/failure"
      )

    Huddlz.Repo.update_all(
      from(h in "huddlz", where: h.id == type(^context.huddl.id, Ecto.UUID)),
      set: [virtual_link: nil]
    )

    context
  end

  step "its recurring occurrences are generated", context do
    assert :ok = perform_job(context.huddl)
    context
  end

  step "its recurring occurrences are generated twice", context do
    assert :ok = perform_job(context.huddl)
    assert :ok = perform_job(context.huddl)
    context
  end

  step "its final recurring generation attempt runs", context do
    job = %Oban.Job{
      args: %{"huddl_id" => context.huddl.id},
      attempt: 3,
      max_attempts: 3
    }

    assert_raise Ash.Error.Invalid, fn ->
      RegenerateRecurringSeries.perform(job)
    end

    context
  end

  step "two future occurrences should exist", context do
    assert length(future_occurrences(context.huddl)) == 2
    context
  end

  step "every occurrence should retain the virtual huddl details and cover image", context do
    for occurrence <- future_occurrences(context.huddl) do
      assert occurrence.virtual_link == "https://meet.example.com/weekly"
      assert occurrence.max_attendees == 24
      assert occurrence.is_private
      assert occurrence.creator_id == context.owner.id
      assert occurrence.group_id == context.group.id
      assert occurrence.time_zone == context.huddl.time_zone

      assert {:ok, image} =
               Communities.get_current_huddl_image(occurrence.id, authorize?: false)

      assert image.filename == "recurrence.jpg"
      assert Storage.exists?(image.storage_path)
      assert Storage.exists?(image.thumbnail_path)
    end

    context
  end

  step "every occurrence should retain both hybrid locations", context do
    for occurrence <- future_occurrences(context.huddl) do
      assert occurrence.physical_location == context.huddl.physical_location
      assert occurrence.virtual_link == "https://meet.example.com/hybrid"
    end

    context
  end

  step "every occurrence should have a capacity of {int}",
       %{args: [capacity]} = context do
    assert Enum.all?(future_occurrences(context.huddl), &(&1.max_attendees == capacity))
    context
  end

  step "the organizer should receive a recurring generation failure notification", context do
    assert {:ok, %{results: notifications}} =
             Notifications.list_for_user(actor: context.owner, page: [limit: 10])

    assert Enum.any?(
             notifications,
             &(&1.trigger == "recurring_huddl_generation_failed")
           )

    context
  end

  defp create_recurring_huddl(context, opts \\ []) do
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
              physical_location: "123 Main St",
              date: Date.add(Date.utc_today(), 1),
              is_recurring: true,
              frequency: "weekly",
              repeat_until: Date.add(Date.utc_today(), 22)
            ],
            opts
          )
        )
      )

    Map.merge(context, %{owner: owner, group: group, huddl: huddl})
  end

  defp attach_cover_image(context) do
    source_file = "test/fixtures/test_image.jpg"
    storage_path = "/uploads/huddl_images/#{context.huddl.id}/recurrence.jpg"
    thumbnail_path = "/uploads/huddl_images/#{context.huddl.id}/recurrence_thumb.jpg"

    assert {:ok, ^storage_path} = Storage.put(source_file, storage_path, "image/jpeg")
    assert {:ok, ^thumbnail_path} = Storage.put(source_file, thumbnail_path, "image/jpeg")

    assert {:ok, _image} =
             HuddlImage
             |> Ash.Changeset.for_create(:create, %{
               filename: "recurrence.jpg",
               content_type: "image/jpeg",
               size_bytes: File.stat!(source_file).size,
               storage_path: storage_path,
               thumbnail_path: thumbnail_path,
               huddl_id: context.huddl.id
             })
             |> Ash.create(authorize?: false)

    context
  end

  defp perform_job(huddl) do
    RegenerateRecurringSeries.perform(%Oban.Job{
      args: %{"huddl_id" => huddl.id},
      attempt: 1,
      max_attempts: 3
    })
  end

  defp future_occurrences(huddl) do
    Huddl
    |> Ash.Query.for_read(:siblings_in_series, %{
      huddl_template_id: huddl.huddl_template_id,
      starting_after: huddl.starts_at
    })
    |> Ash.read!(authorize?: false)
  end
end
