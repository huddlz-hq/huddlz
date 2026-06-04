defmodule Huddlz.Communities.Workers.RegenerateRecurringSeriesTest do
  use Huddlz.DataCase, async: true
  use Oban.Testing, repo: Huddlz.Repo

  alias Huddlz.Communities.Huddl
  alias Huddlz.Communities.Workers.RegenerateRecurringSeries

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

  test "creating a recurring huddl links the template inline and enqueues generation" do
    %{huddl: huddl} = create_recurring()

    # Template linked on the same insert — no re-entrant update needed.
    refute is_nil(huddl.huddl_template_id)

    # Fan-out is deferred: nothing generated until the queue runs.
    assert future_instances(huddl) == []
    assert_enqueued(worker: RegenerateRecurringSeries, args: %{huddl_id: huddl.id})
  end

  test "draining the queue generates the future instances" do
    %{huddl: huddl} = create_recurring()

    assert %{success: 1} = Oban.drain_queue(queue: :default)
    assert length(future_instances(huddl)) == 2
  end

  test "re-running the job regenerates without duplicating" do
    %{huddl: huddl} = create_recurring()

    assert %{success: 1} = Oban.drain_queue(queue: :default)
    assert length(future_instances(huddl)) == 2

    assert :ok = perform_job(RegenerateRecurringSeries, %{huddl_id: huddl.id})
    assert length(future_instances(huddl)) == 2
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
      |> Ash.Changeset.set_argument(:provided_latitude, 30.27)
      |> Ash.Changeset.set_argument(:provided_longitude, -97.74)
      |> Ash.Changeset.for_create(
        :create,
        %{
          title: "Recurring",
          description: "Test",
          date: Date.add(Date.utc_today(), 1),
          start_time: ~T[14:00:00],
          duration_minutes: 60,
          event_type: :in_person,
          physical_location: "123 Main St",
          group_id: group.id,
          is_recurring: true,
          frequency: "weekly",
          repeat_until: Date.add(Date.utc_today(), 22)
        },
        actor: owner
      )
      |> Ash.create!()

    assert parent.latitude == 30.27
    assert %{success: 1} = Oban.drain_queue(queue: :default)

    instances = future_instances(parent)
    assert length(instances) == 2
    assert Enum.all?(instances, &(&1.latitude == 30.27 and &1.longitude == -97.74))
  end

  test "no-ops when the huddl was deleted before the job runs" do
    %{huddl: huddl} = create_recurring()
    Ash.destroy!(huddl, authorize?: false)

    assert :ok = perform_job(RegenerateRecurringSeries, %{huddl_id: huddl.id})
  end
end
