defmodule Huddlz.Communities.Huddl.RecurrenceHelperTest do
  use Huddlz.DataCase, async: true

  alias Huddlz.Communities
  alias Huddlz.Communities.Huddl
  alias Huddlz.Communities.Huddl.RecurrenceHelper
  alias Huddlz.Communities.Huddl.SeriesWindow
  alias Huddlz.Communities.HuddlTemplate
  alias Huddlz.Generator

  setup do
    owner = Generator.generate(Generator.user())
    group = Generator.generate(Generator.group(owner_id: owner.id, actor: owner))

    %{owner: owner, group: group}
  end

  describe "fill_window/2" do
    test "creates the series' next twelve dates", ctx do
      %{template: template} = boundless_series(ctx)

      assert :ok = RecurrenceHelper.fill_window(template)

      assert length(occurrences(template)) == SeriesWindow.horizon()
    end

    test "creates nothing on a second run", ctx do
      %{template: template} = boundless_series(ctx)

      assert :ok = RecurrenceHelper.fill_window(template)
      before = template |> occurrences() |> Enum.map(& &1.id) |> Enum.sort()

      assert :ok = RecurrenceHelper.fill_window(template)

      assert template |> occurrences() |> Enum.map(& &1.id) |> Enum.sort() == before
    end

    test "does not regenerate a date the organizer cancelled", ctx do
      %{template: template, owner: owner} = boundless_series(ctx)
      assert :ok = RecurrenceHelper.fill_window(template)

      cancelled =
        template |> occurrences() |> Enum.sort_by(& &1.starts_at, DateTime) |> Enum.at(3)

      Communities.cancel_huddl!(cancelled, nil, actor: owner)

      assert :ok = RecurrenceHelper.fill_window(template)

      assert Ash.get!(Huddl, cancelled.id, authorize?: false).lifecycle_state == :cancelled

      same_date =
        template
        |> occurrences()
        |> Enum.filter(&(DateTime.to_date(&1.starts_at) == DateTime.to_date(cancelled.starts_at)))

      assert length(same_date) == 1
      assert length(occurrences(template)) == SeriesWindow.horizon()
    end

    test "stops at the series' end date", ctx do
      repeat_until =
        DateTime.new!(Date.add(Generator.eastern_today(), 21), ~T[00:00:00], "Etc/UTC")

      %{template: template} = boundless_series(ctx, repeat_until: repeat_until)

      assert :ok = RecurrenceHelper.fill_window(template)

      assert length(occurrences(template)) == 3
    end

    # Review Focus 2: the source huddl can be hard-deleted out from under a series.
    test "falls back to the latest occurrence when the source pointer is nil", ctx do
      %{template: template} = boundless_series(ctx)
      assert :ok = RecurrenceHelper.fill_window(template)

      template =
        template
        |> Ash.Changeset.for_update(:update, %{source_huddl_id: nil})
        |> Ash.update!(authorize?: false)

      latest = template |> occurrences() |> Enum.max_by(& &1.starts_at, DateTime)

      # Move the cutoff forward so the window has room for new dates.
      assert :ok =
               RecurrenceHelper.fill_window(template, DateTime.add(latest.starts_at, -1, :day))

      assert length(occurrences(template)) > SeriesWindow.horizon()
      assert Enum.all?(occurrences(template), &(&1.title == latest.title))
    end

    test "returns :no_source when the series has no huddlz left", ctx do
      %{template: template} = boundless_series(ctx)

      template
      |> occurrences()
      |> Enum.each(fn huddl ->
        huddl |> Ash.Changeset.for_destroy(:destroy, %{}) |> Ash.destroy!(authorize?: false)
      end)

      template =
        template
        |> Ash.Changeset.for_update(:update, %{source_huddl_id: nil})
        |> Ash.update!(authorize?: false)

      assert {:error, :no_source} = RecurrenceHelper.fill_window(template)
    end

    # Review Focus 5: a gap must not end the series.
    test "generates through a daylight saving gap", ctx do
      %{template: template} =
        boundless_series(ctx,
          time_zone: "America/New_York",
          starts_at_local: ~N[2030-03-03 02:30:00],
          ends_at_local: ~N[2030-03-03 03:30:00]
        )

      cutoff =
        ~N[2030-03-04 12:00:00]
        |> DateTime.from_naive!("America/New_York")
        |> DateTime.shift_zone!("Etc/UTC")

      assert :ok = RecurrenceHelper.fill_window(template, cutoff)

      local_times =
        template
        |> occurrences()
        |> Enum.filter(&(DateTime.compare(&1.starts_at, cutoff) == :gt))
        |> Enum.sort_by(& &1.starts_at, DateTime)
        |> Enum.map(
          &(&1.starts_at
            |> DateTime.shift_zone!("America/New_York")
            |> DateTime.to_time())
        )

      assert [~T[03:00:00], ~T[02:30:00] | _] = local_times
    end
  end

  defp boundless_series(ctx, overrides \\ []) do
    {template_overrides, huddl_overrides} =
      Keyword.split(overrides, [:repeat_until, :time_zone, :starts_at_local, :ends_at_local])

    huddl =
      Generator.generate(
        Generator.huddl(
          Keyword.merge(
            [
              title: "Boundless",
              group_id: ctx.group.id,
              creator_id: ctx.owner.id,
              actor: ctx.owner,
              date: Date.add(Generator.eastern_today(), 7),
              is_recurring: true,
              frequency: "weekly",
              repeat_until: nil
            ],
            huddl_overrides
          )
        )
      )

    template =
      HuddlTemplate
      |> Ash.get!(huddl.huddl_template_id, authorize?: false)
      |> Ash.Changeset.for_update(:update, Map.new(template_overrides))
      |> Ash.update!(authorize?: false)

    %{huddl: huddl, template: template, owner: ctx.owner, group: ctx.group}
  end

  defp occurrences(template) do
    Huddl
    |> Ash.Query.for_read(:siblings_in_series, %{
      huddl_template_id: template.id,
      starting_after: ~U[1970-01-01 00:00:00Z]
    })
    |> Ash.read!(authorize?: false)
  end
end
