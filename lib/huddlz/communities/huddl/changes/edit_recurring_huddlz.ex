defmodule Huddlz.Communities.Huddl.Changes.EditRecurringHuddlz do
  @moduledoc """
  Edit a huddl series
  """
  use Ash.Resource.Change
  require Ash.Query

  alias Huddlz.Communities.Huddl

  def change(changeset, _opts, _context) do
    Ash.Changeset.after_action(changeset, fn _changeset, huddl ->
      case Ash.Changeset.get_argument(changeset, :edit_type) == "all" do
        true ->
          repeat_until = Ash.Changeset.get_argument(changeset, :repeat_until)
          frequency = Ash.Changeset.get_argument(changeset, :frequency)

          update_result =
            huddl.huddl_template
            |> Ash.Changeset.for_update(:update, %{
              repeat_until: repeat_until,
              frequency: frequency
            })
            |> Ash.update(authorize?: false)

          {:ok, huddl_template} = update_result

          old_huddlz =
            Huddl
            |> Ash.Query.filter(starts_at > ^huddl.starts_at)
            |> Ash.Query.filter(huddl_template_id: huddl.huddl_template_id)
            |> Ash.read!()

          for old_huddl <- old_huddlz do
            Ash.destroy(old_huddl, authorize?: false)
          end

          generate_huddlz_from_template(huddl_template, huddl)

          {:ok, huddl}

        _ ->
          {:ok, huddl}
      end
    end)
  end

  defp generate_huddlz_from_template(huddl_template, huddl) do
    case huddl_template.frequency do
      :weekly ->
        starts_at = DateTime.add(huddl.starts_at, 7, :day)
        ends_at = DateTime.add(huddl.ends_at, 7, :day)

        start_at_date = DateTime.to_date(starts_at)

        if Date.before?(start_at_date, huddl_template.repeat_until) do
          new_huddl =
            Ash.Changeset.for_create(Huddl, :create, %{
              starts_at: starts_at,
              ends_at: ends_at,
              event_type: huddl.event_type,
              title: huddl.title,
              description: huddl.description,
              physical_location: huddl.physical_location,
              is_private: huddl.is_private,
              thumbnail_url: huddl.thumbnail_url,
              creator_id: huddl.creator_id,
              group_id: huddl.group_id,
              huddl_template_id: huddl_template.id
            })
            |> Ash.create!(authorize?: false)

          generate_huddlz_from_template(huddl_template, new_huddl)
        end

      :monthly ->
        starts_at = DateTime.add(huddl.starts_at, 30, :day)
        ends_at = DateTime.add(huddl.ends_at, 30, :day)

        start_at_date = DateTime.to_date(starts_at)

        if Date.before?(start_at_date, huddl_template.repeat_until) do
          new_huddl =
            Ash.Changeset.for_create(Huddl, :create, %{
              starts_at: starts_at,
              ends_at: ends_at,
              event_type: huddl.event_type,
              title: huddl.title,
              description: huddl.description,
              physical_location: huddl.physical_location,
              is_private: huddl.is_private,
              thumbnail_url: huddl.thumbnail_url,
              creator_id: huddl.creator_id,
              group_id: huddl.group_id,
              huddl_template_id: huddl_template.id
            })
            |> Ash.create!(authorize?: false)

          generate_huddlz_from_template(huddl_template, new_huddl)
        end
    end
  end
end
