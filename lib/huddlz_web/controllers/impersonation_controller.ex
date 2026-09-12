defmodule HuddlzWeb.ImpersonationController do
  @moduledoc """
  Starts and stops an administrator viewing huddlz as another person.

  Starting keeps the administrator's own session token aside and signs the
  browser session in as the target, so every request and LiveView from then
  on is the target's. Stopping revokes the target's token, puts the
  administrator's back and stamps the record. Bearer tokens are never
  involved: this is a browser-session feature.
  """
  use HuddlzWeb, :controller

  alias AshAuthentication.Jwt
  alias AshAuthentication.TokenResource.Actions, as: Tokens
  alias Huddlz.Accounts
  alias Huddlz.Accounts.{Token, User}
  alias Huddlz.Admin
  alias Huddlz.Admin.Impersonation
  alias HuddlzWeb.BrowserSession

  def create(conn, %{"user_id" => user_id}) do
    admin = conn.assigns[:current_user]

    if User.admin?(admin) and is_nil(get_session(conn, :impersonation_id)) do
      start(conn, admin, user_id)
    else
      conn
      |> put_flash(:error, "You don't have access to the admin area.")
      |> redirect(to: ~p"/agenda")
    end
  end

  def delete(conn, _params) do
    with id when is_binary(id) <- get_session(conn, :impersonation_id),
         admin_token when is_binary(admin_token) <- get_session(conn, :impersonator_token),
         {:ok, %Impersonation{} = record} <-
           Admin.resolve_impersonation_session(id, actor: conn.assigns[:current_user]) do
      stop_record(record)
      revoke(get_session(conn, :user_token))

      conn
      |> BrowserSession.disconnect_live_views()
      |> delete_session(:impersonation_id)
      |> delete_session(:impersonator_token)
      |> put_session(:user_token, admin_token)
      |> put_session(:live_socket_id, BrowserSession.live_socket_id(admin_token))
      |> put_flash(:info, "You are back in your own session")
      |> redirect(to: ~p"/admin/users")
    else
      _ -> redirect(conn, to: ~p"/agenda")
    end
  end

  defp start(conn, admin, user_id) do
    with {:ok, %User{} = target} <- Accounts.get_user(user_id, authorize?: false),
         {:ok, record} <- Admin.start_impersonation(target.id, actor: admin),
         {:ok, token, _claims} <- Jwt.token_for_user(target, %{}, domain: Accounts) do
      conn
      |> BrowserSession.disconnect_live_views()
      |> put_session(:impersonation_id, record.id)
      |> put_session(:impersonator_token, get_session(conn, :user_token))
      |> put_session(:user_token, token)
      |> put_session(:live_socket_id, BrowserSession.live_socket_id(token))
      |> put_flash(:info, "Viewing huddlz as #{target.display_name}")
      |> redirect(to: ~p"/agenda")
    else
      _ ->
        conn
        |> put_flash(:error, "That person cannot be viewed as.")
        |> redirect(to: ~p"/admin/users")
    end
  end

  defp stop_record(%Impersonation{ended_at: nil} = record) do
    Admin.stop_impersonation!(record, actor: record.admin)
  end

  defp stop_record(_record), do: :ok

  defp revoke(token) when is_binary(token), do: Tokens.revoke(Token, token)
  defp revoke(_token), do: :ok
end
