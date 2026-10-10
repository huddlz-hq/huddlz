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
    path =
      if conn.assigns[:current_user],
        do: nil,
        else: AuthReturnTo.validate(conn.query_params["return_to"])

    case path do
      nil ->
        delete_session(conn, :return_to)

      path ->
        put_session(conn, :return_to, %{"path" => path, "at" => System.system_time(:second)})
    end
  end

  def call(conn, _opts), do: conn

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
