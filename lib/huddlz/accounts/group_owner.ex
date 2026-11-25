defmodule Huddlz.Accounts.GroupOwner do
  @moduledoc """
  Who owns a group the actor can see. Apps that never learn a person's
  identity, like the iOS app, report and block "the owner of this group",
  and this lookup turns that into the account behind it without putting
  the account in any response.
  """

  alias Huddlz.Communities.Group

  require Ash.Query

  @doc "The group owner's id, or `:error` when the actor cannot see the group."
  def fetch(group_id, actor) when is_binary(group_id) do
    Group
    |> Ash.Query.for_read(:read, %{}, actor: actor)
    |> Ash.Query.filter(id == ^group_id)
    |> Ash.read_one()
    |> case do
      {:ok, %Group{owner_id: owner_id}} -> {:ok, owner_id}
      _ -> :error
    end
  end

  def fetch(_group_id, _actor), do: :error
end
