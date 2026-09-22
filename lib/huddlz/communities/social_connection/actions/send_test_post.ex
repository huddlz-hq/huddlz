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

    with {:ok, connection} <- Ash.get(SocialConnection, id, actor: context.actor, load: [:group]),
         :ok <- Social.post(connection, Social.test_post_text(connection.group.name)) do
      :ok
    else
      {:error, :revoked} -> {:error, "That place no longer accepts posts. Reconnect it."}
      {:error, %Ash.Error.Query.NotFound{}} -> {:error, "Connection not found"}
      {:error, error} -> {:error, error}
    end
  end
end
