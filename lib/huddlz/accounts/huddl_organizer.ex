defmodule Huddlz.Accounts.HuddlOrganizer do
  @moduledoc """
  Who organized a huddl the actor can see. Apps that never learn a
  person's identity, like the iOS app, report and block "the organizer of
  this huddl", and this lookup turns that into the account behind it
  without putting the account in any response.
  """

  alias Huddlz.Communities.Huddl

  require Ash.Query

  @doc "The organizer's id, or `:error` when the actor cannot see the huddl."
  def fetch(huddl_id, actor) when is_binary(huddl_id) do
    Huddl
    |> Ash.Query.for_read(:read, %{}, actor: actor)
    |> Ash.Query.filter(id == ^huddl_id)
    |> Ash.read_one()
    |> case do
      {:ok, %Huddl{creator_id: creator_id}} -> {:ok, creator_id}
      _ -> :error
    end
  end

  def fetch(_huddl_id, _actor), do: :error
end
