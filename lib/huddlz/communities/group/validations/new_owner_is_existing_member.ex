defmodule Huddlz.Communities.Group.Validations.NewOwnerIsExistingMember do
  @moduledoc """
  Ensures ownership is transferred to a different user who already belongs to the group.
  """

  use Ash.Resource.Validation

  alias Huddlz.Communities

  @impl true
  def init(opts), do: {:ok, opts}

  @impl true
  def supports(_opts), do: [Ash.Changeset]

  @impl true
  def validate(changeset, _opts, _context) do
    new_owner_id = Ash.Changeset.get_argument(changeset, :new_owner_id)

    cond do
      is_nil(new_owner_id) ->
        {:error, field: :new_owner_id, message: "is required"}

      new_owner_id == changeset.data.owner_id ->
        {:error, field: :new_owner_id, message: "is already the group owner"}

      member_of_group?(changeset.data.id, new_owner_id) ->
        :ok

      true ->
        {:error, field: :new_owner_id, message: "must already be a member of this group"}
    end
  end

  defp member_of_group?(group_id, user_id) do
    group_id
    |> Communities.get_by_group!(authorize?: false)
    |> Enum.any?(&(&1.user_id == user_id))
  end
end
