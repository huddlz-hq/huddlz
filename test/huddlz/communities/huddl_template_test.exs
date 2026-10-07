defmodule Huddlz.Communities.HuddlTemplateTest do
  use Huddlz.DataCase, async: true

  alias Huddlz.Communities
  alias Huddlz.Communities.HuddlTemplate

  defp series(opts) do
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
              date: Date.add(eastern_today(), 7),
              is_recurring: true,
              frequency: "weekly"
            ],
            opts
          )
        )
      )

    %{owner: owner, group: group, huddl: huddl}
  end

  defp due_ids do
    HuddlTemplate
    |> Ash.Query.for_read(:due_for_maintenance)
    |> Ash.read!(authorize?: false)
    |> MapSet.new(& &1.id)
  end

  test "a recurring huddl may be created with no end date" do
    %{huddl: huddl} = series(repeat_until: nil)

    template = Ash.get!(HuddlTemplate, huddl.huddl_template_id, authorize?: false)

    assert is_nil(template.repeat_until)
  end

  test "a template records the huddl its occurrences copy" do
    %{huddl: huddl} = series(repeat_until: nil)

    template =
      HuddlTemplate
      |> Ash.get!(huddl.huddl_template_id, authorize?: false)
      |> Ash.load!(:source_huddl, authorize?: false)

    assert template.source_huddl_id == huddl.id
    assert template.source_huddl.id == huddl.id
  end

  test "a cadence is still required" do
    owner = generate(user(role: :user))
    group = generate(group(is_public: true, owner_id: owner.id, actor: owner))

    assert {:error, error} =
             Communities.create_huddl(
               %{
                 title: "No cadence",
                 description: "A recurring huddl with no frequency",
                 event_type: :virtual,
                 virtual_link: "https://example.com/no-cadence",
                 group_id: group.id,
                 date: Date.add(eastern_today(), 7),
                 start_time: ~T[18:30:00],
                 duration_minutes: 60,
                 lifecycle_state: :published,
                 is_recurring: true,
                 repeat_until: nil
               },
               actor: owner
             )

    assert Exception.message(error) =~ "frequency"
  end

  describe "due_for_maintenance" do
    test "includes a boundless series" do
      %{huddl: huddl} = series(repeat_until: nil)

      assert MapSet.member?(due_ids(), huddl.huddl_template_id)
    end

    test "includes a series whose end date is still ahead" do
      %{huddl: huddl} = series(repeat_until: Date.add(eastern_today(), 60))

      assert MapSet.member?(due_ids(), huddl.huddl_template_id)
    end

    test "excludes a series whose end date has passed" do
      %{huddl: huddl} = series(repeat_until: Date.add(eastern_today(), 14))

      HuddlTemplate
      |> Ash.get!(huddl.huddl_template_id, authorize?: false)
      |> Ash.Changeset.for_update(:update, %{
        repeat_until: DateTime.add(DateTime.utc_now(), -1, :day)
      })
      |> Ash.update!(authorize?: false)

      refute MapSet.member?(due_ids(), huddl.huddl_template_id)
    end

    # Pins the defect this filter's earlier `exists(huddlz, ...)` shape had:
    # traversing `huddlz` resolves to Huddl's primary :read, which applies
    # FilterByVisibility and, run with no actor, would silently drop every
    # private group's series. due_for_maintenance must not depend on that
    # traversal, so a private group's series must still be returned.
    test "includes a series in a private group" do
      owner = generate(user(role: :user))
      group = generate(group(is_public: false, owner_id: owner.id, actor: owner))

      huddl =
        generate(
          huddl(
            group_id: group.id,
            creator_id: owner.id,
            actor: owner,
            date: Date.add(eastern_today(), 7),
            is_recurring: true,
            frequency: "weekly",
            repeat_until: nil
          )
        )

      assert MapSet.member?(due_ids(), huddl.huddl_template_id)
    end
  end
end
