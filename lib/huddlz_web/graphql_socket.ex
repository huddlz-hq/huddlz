defmodule HuddlzWeb.GraphqlSocket do
  use Phoenix.Socket

  use Absinthe.Phoenix.Socket,
    schema: HuddlzWeb.GraphqlSchema

  @impl true
  def connect(params, socket, _connect_info) do
    socket =
      case params["token"] do
        nil ->
          Absinthe.Phoenix.Socket.put_options(socket, context: %{actor: nil})

        token ->
          with {:ok, %{"sub" => subject}, _resource} <-
                 AshAuthentication.Jwt.verify(token, Huddlz.Accounts.User),
               {:ok, user} <- AshAuthentication.subject_to_user(subject, Huddlz.Accounts.User) do
            Absinthe.Phoenix.Socket.put_options(socket, context: %{actor: user})
          else
            _ ->
              Absinthe.Phoenix.Socket.put_options(socket, context: %{actor: nil})
          end
      end

    {:ok, socket}
  end

  @impl true
  def id(_socket), do: nil
end
