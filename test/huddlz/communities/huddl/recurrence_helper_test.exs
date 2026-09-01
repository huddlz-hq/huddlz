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
          event_type: :virtual,
          virtual_link: "https://meet.example.com/recurrence",
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
    test "keeps New York wall-clock time through spring-forward", ctx do
      source =
        ctx.huddl
        |> Ash.Changeset.for_update(:update, %{
          starts_at: ~U[2027-03-07 14:00:00Z],
          ends_at: ~U[2027-03-07 15:00:00Z],
          time_zone: "America/New_York"
        })
        |> Ash.update!(authorize?: false)

      template =
        HuddlTemplate
        |> Ash.Changeset.for_create(:create, %{
          frequency: :weekly,
          repeat_until: ~D[2027-03-22],
          starts_at_local: ~N[2027-03-07 09:00:00],
          ends_at_local: ~N[2027-03-07 10:00:00],
          time_zone: "America/New_York"
        })
        |> Ash.create!(authorize?: false)

      RecurrenceHelper.generate_huddlz_from_template(template, source)

      assert [first, second] = generated_huddlz(template)
      assert first.starts_at == ~U[2027-03-14 13:00:00Z]
      assert second.starts_at == ~U[2027-03-21 13:00:00Z]
      assert DateTime.shift_zone!(first.starts_at, first.time_zone).hour == 9
      assert DateTime.shift_zone!(second.starts_at, second.time_zone).hour == 9
    end

    test "keeps New York wall-clock time through fall-back", ctx do
      source =
        ctx.huddl
        |> Ash.Changeset.for_update(:update, %{
          starts_at: ~U[2027-10-31 13:00:00Z],
          ends_at: ~U[2027-10-31 14:00:00Z],
          time_zone: "America/New_York"
        })
        |> Ash.update!(authorize?: false)

      template =
        HuddlTemplate
        |> Ash.Changeset.for_create(:create, %{
          frequency: :weekly,
          repeat_until: ~D[2027-11-15],
          starts_at_local: ~N[2027-10-31 09:00:00],
          ends_at_local: ~N[2027-10-31 10:00:00],
          time_zone: "America/New_York"
        })
        |> Ash.create!(authorize?: false)

      RecurrenceHelper.generate_huddlz_from_template(template, source)

      assert [first, second] = generated_huddlz(template)
      assert first.starts_at == ~U[2027-11-07 14:00:00Z]
      assert second.starts_at == ~U[2027-11-14 14:00:00Z]
      assert DateTime.shift_zone!(first.starts_at, first.time_zone).hour == 9
      assert DateTime.shift_zone!(second.starts_at, second.time_zone).hour == 9
    end

    test "advances a generated spring-forward gap without collapsing its local span", ctx do
      template =
        create_template(ctx.huddl,
          frequency: :weekly,
          repeat_until: ~D[2027-03-15],
          starts_at_local: ~N[2027-03-07 02:30:00],
          ends_at_local: ~N[2027-03-07 03:30:00],
          time_zone: "America/New_York"
        )

      RecurrenceHelper.generate_huddlz_from_template(template, ctx.huddl)

      assert [occurrence] = generated_huddlz(template)
      assert occurrence.starts_at == ~U[2027-03-14 07:30:00Z]
      assert occurrence.ends_at == ~U[2027-03-14 08:30:00Z]
    end

    test "uses the earlier occurrence of a generated fall-back overlap", ctx do
      template =
        create_template(ctx.huddl,
          frequency: :weekly,
          repeat_until: ~D[2027-11-08],
          starts_at_local: ~N[2027-10-31 01:30:00],
          ends_at_local: ~N[2027-10-31 02:30:00],
          time_zone: "America/New_York"
        )

      RecurrenceHelper.generate_huddlz_from_template(template, ctx.huddl)

      assert [occurrence] = generated_huddlz(template)
      assert occurrence.starts_at == ~U[2027-11-07 05:30:00Z]
      assert occurrence.ends_at == ~U[2027-11-07 07:30:00Z]
    end

    test "persists the template zone when the source has diverged", ctx do
      source =
        ctx.huddl
        |> Ash.Changeset.for_update(:update, %{time_zone: "America/Denver"})
        |> Ash.update!(authorize?: false)

      template =
        create_template(source,
          frequency: :weekly,
          repeat_until: ~D[2027-03-15],
          starts_at_local: ~N[2027-03-07 09:00:00],
          ends_at_local: ~N[2027-03-07 10:00:00],
          time_zone: "America/New_York"
        )

      RecurrenceHelper.generate_huddlz_from_template(template, source)

      assert [occurrence] = generated_huddlz(template)
      assert occurrence.starts_at == ~U[2027-03-14 13:00:00Z]
      assert occurrence.time_zone == "America/New_York"
    end

    test "generates weekly recurring huddlz up to repeat_until", ctx do
      repeat_until = Date.add(Date.utc_today(), 22)

      template = create_template(ctx.huddl, frequency: :weekly, repeat_until: repeat_until)

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

      template = create_template(ctx.huddl, frequency: :weekly, repeat_until: repeat_until)

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
        create_template(ctx.huddl,
          interval: 2,
          unit: :week,
          repeat_until: repeat_until
        )

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
    test "generates monthly recurring huddlz up to repeat_until", ctx do
      repeat_until = Date.add(Date.utc_today(), 65)

      template = create_template(ctx.huddl, frequency: :monthly, repeat_until: repeat_until)

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

      template = create_template(ctx.huddl, frequency: :weekly, repeat_until: repeat_until)

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

      template = create_template(ctx.huddl, frequency: :weekly, repeat_until: repeat_until)

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

  defp generated_huddlz(template) do
    Huddl
    |> Ash.Query.filter(huddl_template_id == ^template.id)
    |> Ash.Query.sort(starts_at: :asc)
    |> Ash.read!(authorize?: false)
  end

  defp create_template(source, attrs) do
    local_starts_at =
      source.starts_at |> DateTime.shift_zone!(source.time_zone) |> DateTime.to_naive()

    local_ends_at =
      source.ends_at |> DateTime.shift_zone!(source.time_zone) |> DateTime.to_naive()

    attrs =
      Map.merge(
        %{
          starts_at_local: local_starts_at,
          ends_at_local: local_ends_at,
          time_zone: source.time_zone
        },
        Map.new(attrs)
      )

    HuddlTemplate
    |> Ash.Changeset.for_create(:create, attrs)
    |> Ash.create!(authorize?: false)
  end
end
