defmodule BoundlessRecurrenceSteps do
  use Cucumber.StepDefinition

  import ExUnit.Assertions
  import Huddlz.Generator

  alias Huddlz.Communities
  alias Huddlz.Communities.Huddl
  alias Huddlz.Communities.Workers.MaintainRecurringSeries

  step "a weekly huddl that repeats with no end date", context do
    start_series(context, frequency: "weekly", repeat_until: nil)
  end

  step "a monthly huddl that repeats with no end date", context do
    start_series(context, frequency: "monthly", repeat_until: nil)
  end

  step "a weekly huddl that repeats until three weeks from now", context do
    start_series(context, frequency: "weekly", repeat_until: Date.add(eastern_today(), 21))
  end

  step "the scheduled recurrence run has happened", context do
    run_maintenance(context)
  end

  step "the scheduled recurrence run happens", context do
    run_maintenance(context)
  end

  step "the organizer cancels the fourth upcoming date", context do
    target = context |> upcoming() |> Enum.at(3)
    Communities.cancel_huddl!(target, nil, actor: context.owner)
    Map.put(context, :cancelled, target)
  end

  step "the organizer changes the whole series to weekly", context do
    Communities.update_huddl!(
      context.huddl,
      %{edit_type: "all", frequency: "weekly"},
      actor: context.owner
    )

    context
  end

  step "the organizer extends the whole series by three months", context do
    Communities.update_huddl!(
      context.huddl,
      %{
        edit_type: "all",
        frequency: "weekly",
        repeat_until: Date.add(eastern_today(), 111)
      },
      actor: context.owner
    )

    context
  end

  step "the series should have {int} upcoming dates", %{args: [count]} = context do
    assert length(upcoming(context)) == count
    context
  end

  step "that date should remain cancelled", context do
    reloaded = Ash.get!(Huddl, context.cancelled.id, authorize?: false)
    assert reloaded.lifecycle_state == :cancelled

    same_day =
      context
      |> all_occurrences()
      |> Enum.filter(&(local_date(&1) == local_date(context.cancelled)))

    assert length(same_day) == 1
    context
  end

  step "the upcoming dates should be a week apart", context do
    gaps =
      context
      |> upcoming()
      |> Enum.map(&local_date/1)
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.map(fn [earlier, later] -> Date.diff(later, earlier) end)

    assert Enum.all?(gaps, &(&1 == 7))
    context
  end

  defp start_series(context, opts) do
    owner = generate(user())
    group = generate(group(is_public: true, owner_id: owner.id, actor: owner))

    huddl =
      generate(
        huddl(
          Keyword.merge(
            [
              title: "Boundless series",
              group_id: group.id,
              creator_id: owner.id,
              actor: owner,
              date: Date.add(eastern_today(), 7),
              is_recurring: true
            ],
            opts
          )
        )
      )

    Map.merge(context, %{owner: owner, group: group, huddl: huddl})
  end

  defp run_maintenance(context) do
    assert :ok =
             MaintainRecurringSeries.perform(%Oban.Job{
               args: %{"huddl_template_id" => context.huddl.huddl_template_id},
               attempt: 1,
               max_attempts: 3
             })

    context
  end

  defp all_occurrences(context) do
    Huddl
    |> Ash.Query.for_read(:siblings_in_series, %{
      huddl_template_id: context.huddl.huddl_template_id,
      starting_after: ~U[1970-01-01 00:00:00Z]
    })
    |> Ash.read!(authorize?: false)
    |> Enum.sort_by(& &1.starts_at, DateTime)
  end

  defp upcoming(context) do
    context
    |> all_occurrences()
    |> Enum.filter(&(&1.lifecycle_state in [:draft, :published]))
  end

  defp local_date(huddl) do
    huddl.starts_at |> DateTime.shift_zone!(huddl.time_zone) |> DateTime.to_date()
  end
end
