defmodule HuddlzWeb.AuthReturnSession do
  @moduledoc """
  Keeps a return destination in this browser while password recovery opens an
  email link. It expires after 30 minutes and AuthController consumes it.
  Starting a fresh sign-in, registration or recovery journey forgets the old one.
  """
  @behaviour Plug

  import Plug.Conn
  alias HuddlzWeb.AuthReturnTo

  @lifetime 30 * 60

  @impl true
  def init(opts), do: opts

  @impl true
  def call(%{method: "GET", path_info: [page]} = conn, _opts)
      when page in ["sign-in", "register", "reset"] do
    remember(
      conn,
      conn.assigns[:current_user],
      AuthReturnTo.validate(conn.query_params["return_to"])
    )
  end

  def call(conn, _opts), do: conn

  defp remember(conn, nil = _user, path) when is_binary(path),
    do: put_session(conn, :return_to, %{"path" => path, "at" => System.system_time(:second)})

  defp remember(conn, _user, _path), do: delete_session(conn, :return_to)

  @doc "Returns the unexpired, validated destination remembered in this browser."
  def destination(session, now \\ System.system_time(:second)) do
    case session["return_to"] do
      %{"path" => path, "at" => at} when is_integer(at) and now >= at and now - at <= @lifetime ->
        AuthReturnTo.validate(path)

      _ ->
        nil
    end
  end
end
