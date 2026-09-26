defmodule HuddlzWeb.GraphqlSocketTest do
  use Huddlz.DataCase, async: true

  import Huddlz.Generator
  import Phoenix.ChannelTest, except: [socket: 0]

  alias Huddlz.Accounts
  alias HuddlzWeb.GraphqlSocket

  @endpoint HuddlzWeb.Endpoint
  # Database-backed channel replies can exceed ExUnit's 100 ms default in CI.
  @reply_timeout 1_000

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

  test "suspension disconnects the transport and refuses mutations on an existing channel" do
    person = generate(user(role: :user))
    admin = generate(user(role: :admin))
    channel = open_channel(person)
    topic = channel.id
    :ok = @endpoint.subscribe(topic)

    Accounts.suspend_user!(person, "Spam", actor: admin)
    assert_receive %Phoenix.Socket.Broadcast{topic: ^topic, event: "disconnect"}

    ref =
      push(channel, "doc", %{
        "query" => """
        mutation {
          updateDisplayName(id: "#{person.id}", input: {displayName: "Still here"}) {
            result { id }
            errors { message }
          }
        }
        """
      })

    assert_reply ref,
                 :ok,
                 %{data: %{"updateDisplayName" => %{"result" => nil, "errors" => errors}}},
                 @reply_timeout

    assert errors != []
  end

  test "restoration before the next document cannot revive a revoked connection" do
    person = generate(user(role: :user))
    admin = generate(user(role: :admin))
    channel = open_channel(person)

    suspended = Accounts.suspend_user!(person, "Mistaken report", actor: admin)
    restored = Accounts.restore_user!(suspended, actor: admin)

    old_ref = push(channel, "doc", %{"query" => "{ me { id } }"})
    assert_reply old_ref, :ok, %{data: %{"me" => nil}}, @reply_timeout

    new_ref = restored |> open_channel() |> push("doc", %{"query" => "{ me { id } }"})
    assert_reply new_ref, :ok, %{data: %{"me" => %{"id" => id}}}, @reply_timeout
    assert id == person.id
  end

  defp open_channel(user) do
    {:ok, token, _} = AshAuthentication.Jwt.token_for_user(user, %{}, domain: Accounts)
    {:ok, socket} = connect(GraphqlSocket, %{"token" => token})
    {:ok, _, channel} = subscribe_and_join(socket, "__absinthe__:control")
    channel
  end

  defp socket do
    %Phoenix.Socket{
      transport: :websocket,
      endpoint: HuddlzWeb.Endpoint,
      assigns: %{}
    }
  end
end
