defmodule Huddlz.Communities.Group.Changes.LockLifecycle do
  @moduledoc "Serializes group lifecycle transitions against the current persisted state."
  use Ash.Resource.Change
  require Ash.Query

  alias Huddlz.Communities.{Group, Huddl}

  @impl true
  def change(changeset, _, context) do
    Ash.Changeset.before_action(changeset, fn changeset ->
      group =
        Group
        |> Ash.Query.for_read(:read_with_archived, %{}, authorize?: false)
        |> Ash.Query.filter(id == ^changeset.data.id)
        |> Ash.Query.lock("FOR UPDATE")
        |> Ash.read_one!()

      cond do
        is_nil(group) ->
          Ash.Changeset.add_error(changeset, "This group is no longer available.")

        context.actor && context.actor.id != group.owner_id ->
          Ash.Changeset.add_error(changeset, "Only the current owner can manage this group.")

        changeset.action.name == :archive && not is_nil(group.archived_at) ->
          Ash.Changeset.add_error(changeset, "This group is already archived.")

        changeset.action.name == :archive ->
          validate_huddlz(%{changeset | data: group}, group)

        true ->
          %{changeset | data: group}
      end
    end)
  end

  defp validate_huddlz(changeset, group) do
    # Read without visibility filtering: draft and private records must not hide
    # a scheduled published huddl from the lifecycle invariant.
    titles =
      Huddl
      |> Ash.Query.for_read(:archive_blockers, %{}, authorize?: false)
      |> Ash.Query.filter(group_id == ^group.id)
      |> Ash.Query.select([:title])
      |> Ash.read!()
      |> Enum.map_join(", ", &to_string(&1.title))

    case titles do
      "" ->
        changeset

      titles ->
        Ash.Changeset.add_error(
          changeset,
          "Finish or cancel these huddlz before archiving: #{titles}"
        )
    end
  end
end
