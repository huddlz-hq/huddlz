defmodule Huddlz.Communities.Huddl.Changes.AddHuddlTemplate do
  @moduledoc """
  When a huddl is created as recurring, create its HuddlTemplate and link it on
  the same insert, then enqueue background generation of the series instances.
  """
  use Ash.Resource.Change

  alias Huddlz.Communities.HuddlTemplate
  alias Huddlz.Communities.Workers.RegenerateRecurringSeries

  def change(changeset, _opts, _context) do
    if Ash.Changeset.get_argument(changeset, :is_recurring) == true do
      changeset
      |> Ash.Changeset.before_action(&create_and_link_template/1)
      |> Ash.Changeset.after_action(&set_source_huddl/2)
      |> Ash.Changeset.after_action(&enqueue_generation/2)
    else
      changeset
    end
  end

  # HuddlTemplate has no FK back to the huddl, so create it before the insert
  # and set the id directly. This avoids the re-entrant :update that previously
  # ran inside the :create transaction to backfill huddl_template_id.
  defp create_and_link_template(changeset) do
    schedule =
      HuddlTemplate.wall_clock_schedule(%{
        starts_at: Ash.Changeset.get_attribute(changeset, :starts_at),
        ends_at: Ash.Changeset.get_attribute(changeset, :ends_at),
        time_zone: Ash.Changeset.get_attribute(changeset, :time_zone)
      })

    template =
      HuddlTemplate
      |> Ash.Changeset.for_create(
        :create,
        Map.merge(schedule, %{
          repeat_until: Ash.Changeset.get_argument(changeset, :repeat_until),
          frequency: Ash.Changeset.get_argument(changeset, :frequency)
        }),
        Huddlz.Audit.nested_opts(changeset)
      )
      |> Ash.create!(authorize?: false)

    Ash.Changeset.force_change_attribute(changeset, :huddl_template_id, template.id)
  end

  # The template is created before the huddl exists, so it cannot point back
  # at it yet. Once the huddl has an id, record it as the source whose details
  # every generated occurrence copies.
  defp set_source_huddl(changeset, huddl) do
    HuddlTemplate
    |> Ash.get!(huddl.huddl_template_id, authorize?: false)
    |> Ash.Changeset.for_update(
      :update,
      %{source_huddl_id: huddl.id},
      Huddlz.Audit.nested_opts(changeset)
    )
    |> Ash.update!(authorize?: false)

    {:ok, huddl}
  end

  # Generating up to 104 instances (each a full create) is too much work for the
  # request transaction, so defer it to Oban once the parent huddl commits. The
  # job insert is transactional, so it is rolled back if the create fails.
  defp enqueue_generation(_changeset, huddl) do
    %{huddl_id: huddl.id}
    |> RegenerateRecurringSeries.new()
    |> Oban.insert!()

    {:ok, huddl}
  end
end
