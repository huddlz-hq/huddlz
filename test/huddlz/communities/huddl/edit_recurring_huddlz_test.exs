defmodule Huddlz.Communities.Huddl.Changes.EditRecurringHuddlzTest do
  use Huddlz.DataCase, async: true

  alias Huddlz.Communities
  alias Huddlz.Communities.Huddl
  alias Huddlz.Communities.Huddl.RecurrenceHelper
  alias Huddlz.Communities.HuddlAttendee
  alias Huddlz.Communities.HuddlTemplate
  alias Huddlz.Generator

  # Builds a recurring series: a source huddl linked to a weekly template plus
  # its generated future instances. `is_public` controls whether the group (and
  # therefore every instance) is private — the bug only surfaces for private
  # series, where the old actor-less read could not see the instances.
  defp build_series(is_public, opts \\ []) do
    owner = Generator.generate(Generator.user())

    group =
      Generator.generate(Generator.group(owner_id: owner.id, is_public: is_public, actor: owner))

    starts_at = DateTime.add(DateTime.utc_now(), 1, :day)
    ends_at = DateTime.add(starts_at, 1, :hour)

    source =
      Generator.generate(
        Generator.huddl(
          creator_id: owner.id,
          group_id: group.id,
          is_private: not is_public,
          max_attendees: opts[:max_attendees],
          actor: owner
        )
      )

    # Pin the source's start to a known value so the generated cadence is
    # deterministic (weekly from "tomorrow").
    source =
      source
      |> Ash.Changeset.for_update(:update, %{starts_at: starts_at, ends_at: ends_at},
        actor: owner
      )
      |> Ash.update!()

    repeat_until = opts[:repeat_until] || Date.add(Date.utc_today(), 22)

    template =
      HuddlTemplate
      |> Ash.Changeset.for_create(:create, %{
        frequency: :weekly,
        repeat_until: repeat_until,
        starts_at_local: DateTime.to_naive(starts_at),
        ends_at_local: DateTime.to_naive(ends_at),
        time_zone: source.time_zone
      })
      |> Ash.create!(authorize?: false)

    source =
      source
      |> Ash.Changeset.for_update(:update, %{huddl_template_id: template.id}, actor: owner)
      |> Ash.update!()

    RecurrenceHelper.generate_huddlz_from_template(template, source)

    %{owner: owner, group: group, source: source, template: template, repeat_until: repeat_until}
  end

  # Counts via the visibility-free read so private instances are included —
  # the primary :read would hide them from this actor-less query, masking the
  # very duplication the test checks for.
  defp future_instances(template_id, after_dt) do
    Huddl
    |> Ash.Query.for_read(:siblings_in_series, %{
      huddl_template_id: template_id,
      starting_after: after_dt
    })
    |> Ash.read!(authorize?: false)
  end

  defp edit_all(source, owner, repeat_until) do
    Communities.update_huddl!(
      source,
      %{
        title: "Renamed series",
        edit_type: "all",
        repeat_until: repeat_until,
        frequency: "weekly"
      },
      actor: owner
    )
  end

  defp attendee_entries(huddl) do
    HuddlAttendee
    |> Ash.Query.for_read(:by_huddl, %{huddl_id: huddl.id})
    |> Ash.read!(authorize?: false)
  end

  defp waitlist_entries(huddl) do
    HuddlAttendee
    |> Ash.Query.for_read(:waitlist_for_huddl, %{huddl_id: huddl.id})
    |> Ash.read!(authorize?: false)
  end

  defp instance_on(instances, date) do
    Enum.find(instances, &(DateTime.to_date(&1.starts_at) == date))
  end

  test "edit-all on a private series regenerates instances without duplicating them" do
    %{owner: owner, source: source, template: template, repeat_until: repeat_until} =
      build_series(false)

    assert length(future_instances(template.id, source.starts_at)) == 2

    edit_all(source, owner, repeat_until)

    # With the visibility-free :siblings_in_series read, the 2 private future
    # instances are found and deleted before regeneration, so the count holds at
    # 2. The old actor-less read found 0 and regenerated on top, doubling to 4.
    assert length(future_instances(template.id, source.starts_at)) == 2
  end

  test "edit-all on a public series regenerates without duplicating" do
    %{owner: owner, source: source, template: template, repeat_until: repeat_until} =
      build_series(true)

    assert length(future_instances(template.id, source.starts_at)) == 2

    edit_all(source, owner, repeat_until)

    assert length(future_instances(template.id, source.starts_at)) == 2
  end

  test "reconciliation fills a beginning gap without moving a later RSVP" do
    repeat_until = Date.add(Date.utc_today(), 36)

    %{owner: owner, source: source, template: template} =
      build_series(true, repeat_until: repeat_until)

    [first, subscribed | _] =
      future_instances(template.id, source.starts_at)
      |> Enum.sort_by(& &1.starts_at, DateTime)

    attendee = Generator.generate(Generator.user())

    subscribed
    |> Ash.Changeset.for_update(:rsvp, %{}, actor: attendee)
    |> Ash.update!()

    subscribed_date = DateTime.to_date(subscribed.starts_at)
    Ash.destroy!(first, authorize?: false)

    assert :ok = RecurrenceHelper.reconcile_future_instances(source, template, owner)

    reconciled =
      future_instances(template.id, source.starts_at)
      |> Enum.sort_by(& &1.starts_at, DateTime)

    occurrence = instance_on(reconciled, subscribed_date)

    assert occurrence.id == subscribed.id
    assert Enum.any?(attendee_entries(occurrence), &(&1.user_id == attendee.id))
  end

  test "reconciliation fills a middle gap without moving RSVPs or waitlist entries" do
    repeat_until = Date.add(Date.utc_today(), 36)

    %{owner: owner, source: source, template: template} =
      build_series(true, repeat_until: repeat_until, max_attendees: 2)

    [_first, gap, subscribed | _] =
      future_instances(template.id, source.starts_at)
      |> Enum.sort_by(& &1.starts_at, DateTime)

    attendee = Generator.generate(Generator.user())
    waitlister = Generator.generate(Generator.user())

    subscribed
    |> Ash.Changeset.for_update(:rsvp, %{}, actor: attendee)
    |> Ash.update!()

    subscribed
    |> Ash.reload!()
    |> Ash.Changeset.for_update(:join_waitlist, %{}, actor: waitlister)
    |> Ash.update!()

    subscribed_date = DateTime.to_date(subscribed.starts_at)
    Ash.destroy!(gap, authorize?: false)

    assert :ok = RecurrenceHelper.reconcile_future_instances(source, template, owner)

    reconciled =
      future_instances(template.id, source.starts_at)
      |> Enum.sort_by(& &1.starts_at, DateTime)

    occurrence = instance_on(reconciled, subscribed_date)

    assert occurrence.id == subscribed.id

    assert Enum.any?(
             attendee_entries(occurrence),
             &(&1.user_id == attendee.id and is_nil(&1.waitlisted_at))
           )

    assert Enum.any?(
             waitlist_entries(occurrence),
             &(&1.user_id == waitlister.id and not is_nil(&1.waitlisted_at))
           )
  end

  test "extending a shortened series creates a new active occurrence for a cancelled date" do
    original_repeat_until = Date.add(Date.utc_today(), 36)

    %{owner: owner, source: source, template: template} =
      build_series(true, repeat_until: original_repeat_until)

    dropped =
      template.id
      |> future_instances(source.starts_at)
      |> Enum.max_by(& &1.starts_at, DateTime)

    shortened_source = edit_all(source, owner, Date.add(Date.utc_today(), 16))

    assert %{lifecycle_state: :cancelled} =
             Communities.get_huddl!(dropped.id, actor: owner)

    edit_all(shortened_source, owner, original_repeat_until)

    restored_date = DateTime.to_date(dropped.starts_at)

    restored =
      template.id
      |> future_instances(source.starts_at)
      |> Enum.filter(&(DateTime.to_date(&1.starts_at) == restored_date))

    assert Enum.any?(restored, &(&1.id == dropped.id and &1.lifecycle_state == :cancelled))
    assert Enum.any?(restored, &(&1.id != dropped.id and &1.lifecycle_state == :published))
  end
end
