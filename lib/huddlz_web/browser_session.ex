defmodule HuddlzWeb.BrowserSession do
  @moduledoc "Browser identity metadata and LiveView session topics."
  import Plug.Conn

  alias Huddlz.Accounts.User
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
