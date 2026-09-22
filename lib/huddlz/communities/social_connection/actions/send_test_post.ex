defmodule Huddlz.Communities.SocialConnection.Actions.SendTestPost do
  @moduledoc """
  Posts the test message through the connection so the owner sees it land
  in the channel. The connection is read as the actor, so only what they
  can see can be tested.
  """

  use Ash.Resource.Actions.Implementation

  alias Huddlz.Communities.SocialConnection
  alias Huddlz.Social

  @impl true
  def run(input, _opts, context) do
    id = input.arguments.id

    with {:ok, connection} <- Ash.get(SocialConnection, id, actor: context.actor, load: [:group]) do
      connection
      |> Social.post(Social.test_post_text(connection.group.name))
      |> finish(connection, context.actor)
    end
  end

  defp finish(:ok, _connection, _actor), do: :ok

  defp finish({:error, :revoked}, connection, actor) do
    with {:ok, _} <-
           Huddlz.Communities.mark_social_connection_needs_reconnecting(connection, actor: actor) do
      {:error, "That place no longer accepts posts. Reconnect it."}
    end
  end

  defp finish({:error, _}, _connection, _actor),
    do: {:error, "The test post didn't go through. Try again later."}
end
