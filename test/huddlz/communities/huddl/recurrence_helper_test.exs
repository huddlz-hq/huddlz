defmodule Huddlz.Communities.Huddl.RecurrenceHelperTest do
  use Huddlz.DataCase, async: true

  alias Huddlz.Communities.Huddl
  alias Huddlz.Communities.Huddl.RecurrenceHelper
  alias Huddlz.Communities.HuddlTemplate
  alias Huddlz.Generator

  require Ash.Query

  setup do
    owner = Generator.generate(Generator.user())
    group = Generator.generate(Generator.group(owner_id: owner.id, actor: owner))

    starts_at = DateTime.add(DateTime.utc_now(), 1, :day)
    ends_at = DateTime.add(starts_at, 1, :hour)

    huddl =
      Generator.generate(
        Generator.huddl(
          creator_id: owner.id,
          group_id: group.id,
          actor: owner
        )
      )

    # Overwrite starts_at/ends_at with known values via seed
    huddl =
      huddl
      |> Ash.Changeset.for_update(:update, %{starts_at: starts_at, ends_at: ends_at})
      |> Ash.update!(authorize?: false)

    %{owner: owner, group: group, huddl: huddl, starts_at: starts_at, ends_at: ends_at}
  end

  describe "generate_huddlz_from_template/2 weekly" do
    test "generates weekly recurring huddlz up to repeat_until", ctx do
      repeat_until = Date.add(Date.utc_today(), 22)

      template =
        HuddlTemplate
        |> Ash.Changeset.for_create(:create, %{frequency: :weekly, repeat_until: repeat_until})
        |> Ash.create!(authorize?: false)

      RecurrenceHelper.generate_huddlz_from_template(template, ctx.huddl)

      generated =
        Huddl
        |> Ash.Query.filter(huddl_template_id == ^template.id)
        |> Ash.read!(authorize?: false)

      # With 22 days ahead: day 8 (week 1), day 15 (week 2) should be generated
      # day 22 is NOT before repeat_until (it equals it), so only 2
      assert length(generated) == 2

      dates = generated |> Enum.map(&DateTime.to_date(&1.starts_at)) |> Enum.sort()

      expected_first = Date.add(DateTime.to_date(ctx.starts_at), 7)
      expected_second = Date.add(DateTime.to_date(ctx.starts_at), 14)

      assert dates == Enum.sort([expected_first, expected_second])
    end

    test "generates no huddlz when repeat_until is before next occurrence", ctx do
      repeat_until = Date.add(Date.utc_today(), 1)

      template =
        HuddlTemplate
        |> Ash.Changeset.for_create(:create, %{frequency: :weekly, repeat_until: repeat_until})
        |> Ash.create!(authorize?: false)

      RecurrenceHelper.generate_huddlz_from_template(template, ctx.huddl)

      generated =
        Huddl
        |> Ash.Query.filter(huddl_template_id == ^template.id)
        |> Ash.read!(authorize?: false)

      assert generated == []
    end
  end

  describe "generate_huddlz_from_template/2 every two weeks" do
    test "generates occurrences on the selected weekday every 14 days", ctx do
      repeat_until = Date.add(DateTime.to_date(ctx.starts_at), 43)

      template =
        HuddlTemplate
        |> Ash.Changeset.for_create(:create, %{
          interval: 2,
          unit: :week,
          repeat_until: repeat_until
        })
        |> Ash.create!(authorize?: false)

      RecurrenceHelper.generate_huddlz_from_template(template, ctx.huddl)

      dates =
        Huddl
        |> Ash.Query.filter(huddl_template_id == ^template.id)
        |> Ash.read!(authorize?: false)
        |> Enum.map(&DateTime.to_date(&1.starts_at))
        |> Enum.sort(Date)

      source_date = DateTime.to_date(ctx.starts_at)

      assert dates == [
               Date.add(source_date, 14),
               Date.add(source_date, 28),
               Date.add(source_date, 42)
             ]

      assert Enum.all?(dates, &(Date.day_of_week(&1) == Date.day_of_week(source_date)))
    end

    test "supports a three-week interval", ctx do
      source_date = DateTime.to_date(ctx.starts_at)

      template =
        HuddlTemplate
        |> Ash.Changeset.for_create(:create, %{
          interval: 3,
          unit: :week,
          repeat_until: Date.add(source_date, 64)
        })
        |> Ash.create!(authorize?: false)

      RecurrenceHelper.generate_huddlz_from_template(template, ctx.huddl)

      dates =
        Huddl
        |> Ash.Query.filter(huddl_template_id == ^template.id)
        |> Ash.read!(authorize?: false)
        |> Enum.map(&DateTime.to_date(&1.starts_at))
        |> Enum.sort(Date)

      assert dates == [
               Date.add(source_date, 21),
               Date.add(source_date, 42),
               Date.add(source_date, 63)
             ]
    end

    test "preserves local wall-clock time across daylight-saving changes", ctx do
      starts_at = DateTime.new!(~D[2026-03-01], ~T[09:00:00], "America/New_York")
      ends_at = DateTime.add(starts_at, 1, :hour)
      source = %{ctx.huddl | starts_at: starts_at, ends_at: ends_at}

      template =
        HuddlTemplate
        |> Ash.Changeset.for_create(:create, %{
          interval: 1,
          unit: :week,
          repeat_until: ~D[2026-03-17]
        })
        |> Ash.create!(authorize?: false)

      RecurrenceHelper.generate_huddlz_from_template(template, source)

      local_starts =
        Huddl
        |> Ash.Query.filter(huddl_template_id == ^template.id)
        |> Ash.read!(authorize?: false)
        |> Enum.map(fn huddl ->
          huddl.starts_at
          |> DateTime.shift_zone!("America/New_York")
          |> then(&{DateTime.to_date(&1), DateTime.to_time(&1)})
        end)
        |> Enum.sort()

      assert local_starts == [
               {~D[2026-03-08], ~T[09:00:00]},
               {~D[2026-03-15], ~T[09:00:00]}
             ]
    end
  end

  describe "generate_huddlz_from_template/2 monthly" do
    test "generates monthly recurring huddlz up to repeat_until", ctx do
      repeat_until = Date.add(Date.utc_today(), 65)

      template =
        HuddlTemplate
        |> Ash.Changeset.for_create(:create, %{frequency: :monthly, repeat_until: repeat_until})
        |> Ash.create!(authorize?: false)

      RecurrenceHelper.generate_huddlz_from_template(template, ctx.huddl)

      generated =
        Huddl
        |> Ash.Query.filter(huddl_template_id == ^template.id)
        |> Ash.read!(authorize?: false)

      # With 65 days ahead: day 31 (month 1), day 61 (month 2) should be generated
      assert length(generated) == 2
    end
  end

  describe "generate_huddlz_from_template/3 max instances" do
    test "caps generation at max_instances even when repeat_until is far in the future", ctx do
      # 5 years of weekly = ~260 instances, but should cap at 104
      repeat_until = Date.add(Date.utc_today(), 365 * 5)

      template =
        HuddlTemplate
        |> Ash.Changeset.for_create(:create, %{frequency: :weekly, repeat_until: repeat_until})
        |> Ash.create!(authorize?: false)

      RecurrenceHelper.generate_huddlz_from_template(template, ctx.huddl)

      generated =
        Huddl
        |> Ash.Query.filter(huddl_template_id == ^template.id)
        |> Ash.read!(authorize?: false)

      assert length(generated) == 104
    end
  end

  describe "generate_huddlz_from_template/2 copies huddl properties" do
    test "new huddlz inherit title, description, and other fields from source", ctx do
      repeat_until = Date.add(Date.utc_today(), 10)

      template =
        HuddlTemplate
        |> Ash.Changeset.for_create(:create, %{frequency: :weekly, repeat_until: repeat_until})
        |> Ash.create!(authorize?: false)

      RecurrenceHelper.generate_huddlz_from_template(template, ctx.huddl)

      generated =
        Huddl
        |> Ash.Query.filter(huddl_template_id == ^template.id)
        |> Ash.read!(authorize?: false)

      assert length(generated) == 1
      [new_huddl] = generated
      assert new_huddl.title == ctx.huddl.title
      assert new_huddl.description == ctx.huddl.description
      assert new_huddl.event_type == ctx.huddl.event_type
      assert new_huddl.group_id == ctx.huddl.group_id
      assert new_huddl.creator_id == ctx.huddl.creator_id
    end
  end

  describe "weekly recurrence interval validation" do
    test "accepts intervals one through four and rejects missing or unsupported values", ctx do
      Enum.each(1..4, fn interval ->
        assert {:ok, huddl} = create_recurring_huddl(ctx, interval)
        template = Ash.load!(huddl, :huddl_template, authorize?: false).huddl_template
        assert template.interval == interval
        assert template.unit == :week
      end)

      for interval <- [nil, 0, -1, 5] do
        assert {:error, %Ash.Error.Invalid{}} = create_recurring_huddl(ctx, interval)
      end
    end
  end

  defp create_recurring_huddl(ctx, interval) do
    attrs = %{
      title: "Interval #{inspect(interval)} #{System.unique_integer([:positive])}",
      date: Date.add(Date.utc_today(), 1),
      start_time: ~T[09:00:00],
      duration_minutes: 60,
      event_type: :in_person,
      physical_location: "123 Main St",
      group_id: ctx.group.id,
      is_recurring: true,
      frequency: "weekly",
      repeat_until: Date.add(Date.utc_today(), 90)
    }

    attrs = if is_nil(interval), do: attrs, else: Map.put(attrs, :recurrence_interval, interval)

    Huddl
    |> Ash.Changeset.for_create(:create, attrs, actor: ctx.owner)
    |> Ash.create()
  end
end
