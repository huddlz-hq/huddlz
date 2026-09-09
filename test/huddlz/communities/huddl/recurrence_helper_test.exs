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
    test "returns an error instead of raising for a spring-forward gap", ctx do
      template =
        HuddlTemplate
        |> Ash.Changeset.for_create(:create, %{
          frequency: :weekly,
          repeat_until: ~D[2030-03-17],
          starts_at_local: ~N[2030-03-03 02:30:00],
          ends_at_local: ~N[2030-03-03 03:30:00],
          time_zone: "America/New_York"
        })
        |> Ash.create!(authorize?: false)

      assert {:error, message} =
               RecurrenceHelper.generate_huddlz_from_template(template, ctx.huddl)

      assert message =~ "does not exist in America/New_York"
    end

    test "generates weekly recurring huddlz up to repeat_until", ctx do
      repeat_until = Date.add(Huddlz.Generator.eastern_today(), 22)

      template =
        HuddlTemplate
        |> Ash.Changeset.for_create(
          :create,
          template_attrs(ctx.huddl, %{frequency: :weekly, repeat_until: repeat_until})
        )
        |> Ash.create!(authorize?: false)

      RecurrenceHelper.generate_huddlz_from_template(template, ctx.huddl)

      generated =
        Huddl
        |> Ash.Query.filter(huddl_template_id == ^template.id)
        |> Ash.read!(authorize?: false)

      # Include day 22, the selected final local date, along with days 8 and 15.
      assert length(generated) == 3

      dates = generated |> Enum.map(&DateTime.to_date(&1.starts_at)) |> Enum.sort()

      expected_first = Date.add(DateTime.to_date(ctx.starts_at), 7)
      expected_second = Date.add(DateTime.to_date(ctx.starts_at), 14)

      expected_third = Date.add(DateTime.to_date(ctx.starts_at), 21)

      assert dates == Enum.sort([expected_first, expected_second, expected_third])
    end

    test "generates no huddlz when repeat_until is before next occurrence", ctx do
      repeat_until = Date.add(Huddlz.Generator.eastern_today(), 1)

      template =
        HuddlTemplate
        |> Ash.Changeset.for_create(
          :create,
          template_attrs(ctx.huddl, %{frequency: :weekly, repeat_until: repeat_until})
        )
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
        |> Ash.Changeset.for_create(
          :create,
          template_attrs(ctx.huddl, %{
            interval: 2,
            unit: :week,
            repeat_until: repeat_until
          })
        )
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
  end

  describe "generate_huddlz_from_template/2 monthly" do
    test "keeps the selected calendar day across ordinary months", ctx do
      starts_at = ~U[2026-01-15 18:30:00Z]
      huddl = move_huddl(ctx.huddl, starts_at)

      template =
        HuddlTemplate
        |> Ash.Changeset.for_create(
          :create,
          template_attrs(huddl, %{frequency: :monthly, repeat_until: ~D[2026-05-01]})
        )
        |> Ash.create!(authorize?: false)

      RecurrenceHelper.generate_huddlz_from_template(template, huddl)

      assert generated_dates(template) == [
               ~D[2026-02-15],
               ~D[2026-03-15],
               ~D[2026-04-15]
             ]
    end

    test "clamps January 31 to month end and restores day 31 in a leap year", ctx do
      huddl = move_huddl(ctx.huddl, ~U[2024-01-31 18:30:00Z])

      template =
        HuddlTemplate
        |> Ash.Changeset.for_create(
          :create,
          template_attrs(huddl, %{frequency: :monthly, repeat_until: ~D[2024-05-01]})
        )
        |> Ash.create!(authorize?: false)

      RecurrenceHelper.generate_huddlz_from_template(template, huddl)

      assert generated_dates(template) == [
               ~D[2024-02-29],
               ~D[2024-03-31],
               ~D[2024-04-30]
             ]
    end

    test "keeps local month ends and overnight duration across daylight saving", ctx do
      template =
        HuddlTemplate
        |> Ash.Changeset.for_create(:create, %{
          frequency: :monthly,
          repeat_until: ~D[2028-05-01],
          starts_at_local: ~N[2028-01-31 23:30:00],
          ends_at_local: ~N[2028-02-01 01:30:00],
          time_zone: "America/New_York"
        })
        |> Ash.create!(authorize?: false)

      assert :ok = RecurrenceHelper.generate_huddlz_from_template(template, ctx.huddl)

      generated =
        Huddl
        |> Ash.Query.filter(huddl_template_id == ^template.id)
        |> Ash.read!(authorize?: false)
        |> Enum.sort_by(& &1.starts_at, DateTime)

      assert Enum.map(generated, fn huddl ->
               {huddl.starts_at
                |> DateTime.shift_zone!(template.time_zone)
                |> DateTime.to_naive(),
                huddl.ends_at |> DateTime.shift_zone!(template.time_zone) |> DateTime.to_naive()}
             end) == [
               {~N[2028-02-29 23:30:00], ~N[2028-03-01 01:30:00]},
               {~N[2028-03-31 23:30:00], ~N[2028-04-01 01:30:00]},
               {~N[2028-04-30 23:30:00], ~N[2028-05-01 01:30:00]}
             ]
    end

    test "clamps January 31 to February 28 in a non-leap year", ctx do
      huddl = move_huddl(ctx.huddl, ~U[2025-01-31 18:30:00Z])

      template =
        HuddlTemplate
        |> Ash.Changeset.for_create(
          :create,
          template_attrs(huddl, %{frequency: :monthly, repeat_until: ~D[2025-04-01]})
        )
        |> Ash.create!(authorize?: false)

      RecurrenceHelper.generate_huddlz_from_template(template, huddl)

      assert generated_dates(template) == [
               ~D[2025-02-28],
               ~D[2025-03-31]
             ]
    end
  end

  describe "generate_huddlz_from_template/3 max instances" do
    test "caps generation at max_instances even when repeat_until is far in the future", ctx do
      # 5 years of weekly = ~260 instances, but should cap at 104
      repeat_until = Date.add(Huddlz.Generator.eastern_today(), 365 * 5)

      template =
        HuddlTemplate
        |> Ash.Changeset.for_create(
          :create,
          template_attrs(ctx.huddl, %{frequency: :weekly, repeat_until: repeat_until})
        )
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
      repeat_until = Date.add(Huddlz.Generator.eastern_today(), 10)

      template =
        HuddlTemplate
        |> Ash.Changeset.for_create(
          :create,
          template_attrs(ctx.huddl, %{frequency: :weekly, repeat_until: repeat_until})
        )
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

  defp move_huddl(huddl, starts_at) do
    duration = DateTime.diff(huddl.ends_at, huddl.starts_at, :second)

    huddl
    |> Ash.Changeset.for_update(:update, %{
      starts_at: starts_at,
      ends_at: DateTime.add(starts_at, duration, :second)
    })
    |> Ash.update!(authorize?: false)
  end

  defp generated_dates(template) do
    Huddl
    |> Ash.Query.filter(huddl_template_id == ^template.id)
    |> Ash.read!(authorize?: false)
    |> Enum.map(&DateTime.to_date(&1.starts_at))
    |> Enum.sort(Date)
  end

  defp template_attrs(huddl, attrs) do
    HuddlTemplate.wall_clock_schedule(huddl)
    |> Map.merge(attrs)
  end
end
