defmodule Huddlz.Communities.Workers.SweepRecurringSeriesTest do
  use Huddlz.DataCase, async: true
  use Oban.Testing, repo: Huddlz.Repo

  alias Huddlz.Communities.HuddlTemplate
  alias Huddlz.Communities.Workers.MaintainRecurringSeries
  alias Huddlz.Communities.Workers.SweepRecurringSeries
  alias Huddlz.Generator

  defp series(opts \\ []) do
    owner = generate(user(role: :user))
    group = generate(group(is_public: true, owner_id: owner.id, actor: owner))

    huddl =
      generate(
        huddl(
          Keyword.merge(
            [
              group_id: group.id,
              creator_id: owner.id,
              actor: owner,
              date: Date.add(Generator.eastern_today(), 7),
              is_recurring: true,
              frequency: "weekly",
              repeat_until: nil
            ],
            opts
          )
        )
      )

    %{owner: owner, group: group, huddl: huddl}
  end

  defp jobs_for(template_id) do
    Enum.count(all_enqueued(worker: MaintainRecurringSeries), fn job ->
      job.args["huddl_template_id"] == template_id
    end)
  end

  test "enqueues maintenance for a boundless series" do
    %{huddl: huddl} = series()

    # Clear the job enqueued by creation so the sweep's insert is the only
    # one in play.
    Huddlz.Repo.delete_all(Oban.Job)

    assert :ok = SweepRecurringSeries.perform(%Oban.Job{args: %{}})

    assert jobs_for(huddl.huddl_template_id) == 1
  end

  test "does not enqueue for a series whose end date has passed" do
    %{huddl: huddl} = series(repeat_until: Date.add(Generator.eastern_today(), 14))

    # The :create action rejects a past repeat_until, so push the template's
    # end date into the past directly, the same way huddl_template_test.exs
    # exercises the expired branch of :due_for_maintenance.
    HuddlTemplate
    |> Ash.get!(huddl.huddl_template_id, authorize?: false)
    |> Ash.Changeset.for_update(:update, %{
      repeat_until: DateTime.add(DateTime.utc_now(), -1, :day)
    })
    |> Ash.update!(authorize?: false)

    Huddlz.Repo.delete_all(Oban.Job)

    assert :ok = SweepRecurringSeries.perform(%Oban.Job{args: %{}})

    assert jobs_for(huddl.huddl_template_id) == 0
  end
end
