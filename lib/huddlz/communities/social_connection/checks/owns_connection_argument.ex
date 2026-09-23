defmodule Huddlz.Communities.SocialConnection.Checks.OwnsConnectionArgument do
  @moduledoc """
  Authorizes a generic action whose `id` argument names a social connection
  of a group the actor owns. Generic actions have no record to write an
  expression policy against, so the lookup happens here.
  """

  use Ash.Policy.SimpleCheck

  require Ash.Query

  alias Huddlz.Communities.SocialConnection

  @impl true
  def describe(_opts), do: "actor owns the group of the connection named by id"

  @impl true
  def match?(%{id: actor_id}, %{subject: %{arguments: %{id: id}}}, _opts) when is_binary(id) do
    SocialConnection
    |> Ash.Query.filter(id == ^id and group.owner_id == ^actor_id)
    |> Ash.exists?(authorize?: false)
  end

  def match?(_actor, _context, _opts), do: false
end
