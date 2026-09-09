defmodule Huddlz.Communities.Changes.RequireActiveGroup do
  @moduledoc "Locks the parent group so new activity cannot race group archival."
  use Ash.Resource.Change
  require Ash.Query

  alias Huddlz.Communities.{Group, Huddl}

  @impl true
  def change(changeset, _, _) do
    Ash.Changeset.before_action(changeset, &require_active/1, prepend?: true)
  end

  defp parent_group_id(%{resource: Group, data: %{id: id}}), do: {:ok, id}

  defp parent_group_id(changeset) do
    group_id = value(changeset, :group_id)
    huddl_id = value(changeset, :huddl_id)

    cond do
      group_id ->
        {:ok, group_id}

      huddl_id ->
        with {:ok, huddl} <-
               Ash.get(Huddl, huddl_id, action: :read_for_group_lifecycle, authorize?: false) do
          {:ok, huddl.group_id}
        end

      true ->
        {:ok, nil}
    end
  end

  defp value(changeset, field),
    do:
      Ash.Changeset.get_argument(changeset, field) ||
        Ash.Changeset.get_attribute(changeset, field)

  defp require_active(changeset) do
    case parent_group_id(changeset) do
      {:ok, group_id} -> require_active_group(changeset, group_id)
      {:error, error} -> Ash.Changeset.add_error(changeset, error)
    end
  end

  defp require_active_group(changeset, nil), do: changeset

  defp require_active_group(changeset, id) do
    group =
      Group
      |> Ash.Query.for_read(:read_with_archived, %{}, authorize?: false)
      |> Ash.Query.filter(id == ^id)
      |> Ash.Query.lock("FOR UPDATE")
      |> Ash.read_one!()

    case group do
      %{archived_at: nil} ->
        changeset

      _ ->
        Ash.Changeset.add_error(changeset,
          field: :base,
          message: "This group is archived or unavailable. Restore it before making changes."
        )
    end
  end
end
