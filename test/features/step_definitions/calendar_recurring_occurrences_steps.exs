defmodule CalendarRecurringOccurrencesSteps do
  use Cucumber.StepDefinition

  import ExUnit.Assertions
  import Huddlz.Generator
  import PhoenixTest

  alias Huddlz.Communities
  alias Huddlz.Communities.Huddl
  alias Huddlz.Communities.Workers.RegenerateRecurringSeries

  step "the group has a published recurring huddl with occurrences this Tuesday and next Tuesday",
       context do
    this_tuesday = next_tuesday(Date.utc_today())
    next_tuesday = Date.add(this_tuesday, 7)

    first_occurrence =
      generate(
        huddl(
          title: "Tuesday Code and Coffee",
          group_id: context.calendar_group.id,
          creator_id: context.calendar_owner.id,
          actor: context.calendar_owner,
          date: this_tuesday,
          start_time: ~T[09:00:00],
          duration_minutes: 60,
          lifecycle_state: :published,
          is_private: false,
          is_recurring: true,
          frequency: "weekly",
          repeat_until: Date.add(next_tuesday, 1)
        )
      )

    :ok =
      RegenerateRecurringSeries.perform(%Oban.Job{
        args: %{"huddl_id" => first_occurrence.id},
        attempt: 1,
        max_attempts: 3
      })

    [second_occurrence] =
      Huddl
      |> Ash.Query.for_read(:siblings_in_series, %{
        huddl_template_id: first_occurrence.huddl_template_id,
        starting_after: first_occurrence.starts_at
      })
      |> Ash.read!(authorize?: false)

    Map.merge(context, %{
      this_tuesday: this_tuesday,
      next_tuesday: next_tuesday,
      this_tuesday_occurrence: first_occurrence,
      next_tuesday_occurrence: second_occurrence
    })
  end

  step "I view each occurrence's week in Calendar", context do
    Map.put(
      context,
      :session,
      visit(context.session, week_path(context.this_tuesday))
    )
  end

  step "I see the occurrence on the correct Tuesday", context do
    assert Date.day_of_week(context.this_tuesday) == 2
    assert Date.day_of_week(context.next_tuesday) == 2

    assert_occurrence_week(
      context.session,
      context.this_tuesday,
      context.this_tuesday_occurrence,
      context.next_tuesday_occurrence
    )

    next_week_session = visit(context.session, week_path(context.next_tuesday))

    assert_occurrence_week(
      next_week_session,
      context.next_tuesday,
      context.next_tuesday_occurrence,
      context.this_tuesday_occurrence
    )

    Map.put(context, :session, next_week_session)
  end

  step "I am going to this Tuesday's occurrence only", context do
    Communities.rsvp_huddl!(context.this_tuesday_occurrence, actor: context.current_user)
    context
  end

  step "I view Calendar Week containing this Tuesday", context do
    Map.put(context, :session, visit(context.session, week_path(context.this_tuesday)))
  end

  step "this Tuesday's occurrence is marked {string}", %{args: [marker]} = context do
    assert_has(
      context.session,
      relationship_selector(context.this_tuesday_occurrence),
      text: marker
    )

    context
  end

  step "I view Calendar Week containing next Tuesday", context do
    Map.put(context, :session, visit(context.session, week_path(context.next_tuesday)))
  end

  step "next Tuesday's occurrence has no Personal relationship marker", context do
    assert_has(
      context.session,
      "#calendar-week-list #calendar-huddl-#{context.next_tuesday_occurrence.id}"
    )

    refute_has(context.session, relationship_selector(context.next_tuesday_occurrence))
    context
  end

  defp next_tuesday(today) do
    case Integer.mod(2 - Date.day_of_week(today), 7) do
      0 -> Date.add(today, 7)
      days_until_tuesday -> Date.add(today, days_until_tuesday)
    end
  end

  defp week_path(date), do: "/calendar?view=week&date=#{Date.to_iso8601(date)}"

  defp assert_occurrence_week(session, tuesday, expected_occurrence, other_occurrence) do
    week_start = Date.add(tuesday, -2)
    week_end = Date.add(tuesday, 4)

    assert_has(
      session,
      "#calendar-week-range",
      text: "Week from #{format_full_date(week_start)} through #{format_full_date(week_end)}"
    )

    assert_has(
      session,
      "#calendar-week-list #calendar-huddl-#{expected_occurrence.id}" <>
        "[data-starts-at^='#{Date.to_iso8601(tuesday)}T09:00:00']"
    )

    refute_has(session, "#calendar-week-list #calendar-huddl-#{other_occurrence.id}")
  end

  defp relationship_selector(huddl) do
    "#calendar-huddl-#{huddl.id} [data-testid='calendar-relationship']"
  end

  defp format_full_date(date), do: Calendar.strftime(date, "%A, %B %-d, %Y")
end
