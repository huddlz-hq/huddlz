defmodule HuddlzWeb.GraphqlSocket do
  use Phoenix.Socket

  use Absinthe.Phoenix.Socket,
    schema: HuddlzWeb.GraphqlSchema

  alias AshAuthentication.TokenResource.Actions, as: Tokens
  alias Huddlz.Accounts.{Token, User}

  @impl true
  def connect(params, socket, _connect_info) do
    socket =
      case params["token"] do
        nil ->
          Absinthe.Phoenix.Socket.put_options(socket, context: %{actor: nil})

        token ->
          with {:ok, %{"sub" => subject, "jti" => jti, "exp" => expires_at}, _resource} <-
                 AshAuthentication.Jwt.verify(token, User),
               {:ok, user} <- AshAuthentication.subject_to_user(subject, User),
               false <- User.suspended?(user) do
            Absinthe.Phoenix.Socket.put_options(socket,
              context: %{actor: user, graphql_session: %{jti: jti, expires_at: expires_at}}
            )
          else
            _ ->
              Absinthe.Phoenix.Socket.put_options(socket, context: %{actor: nil})
          end
      end

    {:ok, socket}
  end

  @impl true
  def id(%{assigns: %{absinthe: %{opts: opts}}}) do
    case opts[:context][:actor] do
      %User{id: id} -> "graphql_users:#{id}"
      _ -> nil
    end
  end

  def id(_socket), do: nil

  # A channel outlives the request that authenticated it. Check the credential
  # and current account on every document, including before a disconnect lands.
  def refresh_context(%{actor: %User{id: id}, graphql_session: session} = context) do
    actor =
      with true <- session.expires_at > System.system_time(:second),
           true <- Tokens.valid_jti?(Token, session.jti),
           {:ok, %User{suspended_at: nil} = user} <- Ash.get(User, id, authorize?: false) do
        user
      else
        _ -> nil
      end

    %{context | actor: actor}
  end

  def refresh_context(context), do: context
end
