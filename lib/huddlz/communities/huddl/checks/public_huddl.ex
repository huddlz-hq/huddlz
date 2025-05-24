defmodule Huddlz.Communities.Huddl.Checks.PublicHuddl do
  @moduledoc """
  Check if the huddl is public (not private and in a public group).
  """
  use Ash.Policy.SimpleCheck

  alias Huddlz.Communities.Group

  def describe(_opts) do
    "huddl is public"
  end

  def match?(_actor, %{resource: _resource, query: %Ash.Query{}}, _opts) do
    # For queries, we'll handle this through preparations
    true
  end

  def match?(_actor, %{resource: _resource, changeset: %Ash.Changeset{data: huddl}}, _opts) do
    check_public(huddl)
  end

  def match?(_actor, %{resource: _resource} = context, _opts) do
    # Try to get the huddl
    case Map.get(context, :record) do
      %{is_private: false, group_id: group_id} ->
        # Check if the group is public
        case Ash.get(Group, group_id, authorize?: false) do
          {:ok, %{is_public: true}} -> true
          _ -> false
        end

      _ ->
        false
    end
  end

  def match?(_actor, _context, _opts), do: false

  defp check_public(%{is_private: true}), do: false

  defp check_public(%{is_private: false, group_id: group_id}) do
    case Ash.get(Group, group_id, authorize?: false) do
      {:ok, %{is_public: true}} -> true
      _ -> false
    end
  end

  defp check_public(_), do: false
end
