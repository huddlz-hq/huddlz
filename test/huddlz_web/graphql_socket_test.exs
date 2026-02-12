defmodule HuddlzWeb.GraphqlSocketTest do
  use Huddlz.DataCase, async: true

  import Huddlz.Generator

  alias HuddlzWeb.GraphqlSocket

  describe "connect/3" do
    test "connects with actor: nil when no token provided" do
      assert {:ok, socket} = GraphqlSocket.connect(%{}, socket(), %{})

      assert socket.assigns.absinthe.opts[:context][:actor] == nil
    end

    test "connects with authenticated user when valid token provided" do
      user = generate(user(role: :user))

      {:ok, token, _claims} =
        AshAuthentication.Jwt.token_for_user(user, %{}, domain: Huddlz.Accounts)

      assert {:ok, socket} = GraphqlSocket.connect(%{"token" => token}, socket(), %{})

      %{id: actor_id} = socket.assigns.absinthe.opts[:context][:actor]
      assert actor_id == user.id
    end

    test "connects with actor: nil when invalid token provided" do
      assert {:ok, socket} =
               GraphqlSocket.connect(%{"token" => "invalid.jwt.token"}, socket(), %{})

      assert socket.assigns.absinthe.opts[:context][:actor] == nil
    end
  end

  defp socket do
    %Phoenix.Socket{
      transport: :websocket,
      endpoint: HuddlzWeb.Endpoint,
      assigns: %{}
    }
  end
end
