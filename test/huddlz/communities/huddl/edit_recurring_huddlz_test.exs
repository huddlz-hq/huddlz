defmodule Huddlz.Communities.Huddl.Changes.EditRecurringHuddlzTest do
  use Huddlz.DataCase, async: true

  alias Huddlz.Communities.Huddl
  alias Huddlz.Communities.Huddl.RecurrenceHelper
  alias Huddlz.Communities.HuddlTemplate
  alias Huddlz.Generator

  # Builds a recurring series: a source huddl linked to a weekly template plus
  # its generated future instances. `is_public` controls whether the group (and
  # therefore every instance) is private — the bug only surfaces for private
  # series, where the old actor-less read could not see the instances.
  defp build_series(is_public) do
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

    repeat_until = Date.add(Date.utc_today(), 22)

    template =
      HuddlTemplate
      |> Ash.Changeset.for_create(:create, %{frequency: :weekly, repeat_until: repeat_until})
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
    source
    |> Ash.Changeset.for_update(
      :update,
      %{
        title: "Renamed series",
        edit_type: "all",
        repeat_until: repeat_until,
        frequency: "weekly"
      },
      actor: owner
    )
    |> Ash.update!()
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
end
