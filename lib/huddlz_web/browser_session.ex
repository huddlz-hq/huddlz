defmodule HuddlzWeb.BrowserSession do
  @moduledoc "Browser identity metadata and LiveView session topics."
  import Plug.Conn

  alias AshAuthentication.TokenResource.Actions, as: Tokens
  alias Huddlz.Accounts.{Token, User}
  alias Huddlz.Admin
  alias Huddlz.Admin.Impersonation

  def init(opts), do: opts

  def call(conn, _opts) do
    {user, _record} = resolve(conn.assigns[:current_user], get_session(conn, :impersonation_id))
    assign(conn, :current_user, user)
  end

  def resolve(%User{} = user, id) when is_binary(id) do
    case Admin.resolve_impersonation_session(id, actor: user) do
      {:ok, %Impersonation{} = record} ->
        {Ash.Resource.put_metadata(user, :impersonation, record), record}

      _ ->
        {Ash.Resource.put_metadata(user, :impersonation, nil), nil}
    end
  end

  def resolve(user, _id), do: {user, nil}

  @doc "End impersonation and discard both saved identities before sign-out or reauthentication."
  def finalize_impersonation(conn) do
    case get_session(conn, :impersonation_id) do
      id when is_binary(id) ->
        stop_impersonation(id, conn.assigns[:current_user])

        revoke(get_session(conn, :user_token))
        revoke(get_session(conn, :impersonator_token))

        conn
        |> delete_session(:impersonation_id)
        |> delete_session(:impersonator_token)
        |> delete_session(:user_token)

      _ ->
        conn
    end
  end

  defp stop_impersonation(id, user) do
    case Admin.resolve_impersonation_session(id, actor: user) do
      {:ok, %Impersonation{} = record} ->
        Admin.stop_impersonation!(record, actor: record.admin)

      _ ->
        :ok
    end
  end

  defp revoke(token) when is_binary(token), do: Tokens.revoke(Token, token)
  defp revoke(_token), do: :ok

  def disconnect_live_views(conn) do
    case get_session(conn, :live_socket_id) do
      topic when is_binary(topic) ->
        HuddlzWeb.Endpoint.broadcast(topic, "disconnect", %{})
        conn

      _ ->
        conn
    end
  end

  def live_socket_id(token), do: "users_sessions:#{Base.url_encode64(token)}"
end
