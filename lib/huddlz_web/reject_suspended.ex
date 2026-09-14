defmodule HuddlzWeb.RejectSuspended do
  @moduledoc """
  Turns a suspended account away at every HTTP entry point.

  Suspension revokes the account's tokens, so an existing session or bearer
  token already fails to load a user. What this plug adds is the reason:
  a browser still carrying the dead token is signed out with a word about
  why, and a request that somehow arrives with a suspended actor (the
  moment between marking and revocation) is refused instead of served.
  Runs before activity is counted, so a refused request never counts.

  Public browsing is untouched: once the session is cleared the visitor
  is an ordinary signed-out one.
  """

  import Plug.Conn
  import Phoenix.Controller, only: [redirect: 2]

  use HuddlzWeb, :verified_routes

  alias AshAuthentication.Jwt.Config, as: JwtConfig
  alias AshAuthentication.TokenResource.Actions, as: Tokens
  alias Huddlz.Accounts.{Token, User}

  def init(mode) when mode in [:browser, :api], do: mode

  @doc """
  The session loader deletes a token it cannot honour, which is exactly a
  suspended account's token. `HuddlzWeb.ErrorContext` calls this before
  the first load so the browser step can still tell the person why they
  were signed out.
  """
  def remember_session_token(conn) do
    put_private(conn, :session_token_before_load, get_session(conn, :user_token))
  end

  def call(conn, :browser) do
    case conn.assigns[:current_user] do
      %User{suspended_at: %DateTime{}} = user ->
        revoke(get_session(conn, :user_token))
        HuddlzWeb.BrowserSession.disconnect_live_views(conn)
        sign_out(conn, user)

      %User{} ->
        conn

      _none ->
        reject_stale_session(conn)
    end
  end

  def call(conn, :api) do
    case conn.assigns[:current_user] || Ash.PlugHelpers.get_actor(conn) do
      %User{suspended_at: %DateTime{}} ->
        conn
        |> put_status(:unauthorized)
        |> Phoenix.Controller.json(%{error: "This account is suspended"})
        |> halt()

      _ ->
        conn
    end
  end

  # No user could be loaded, but the session still holds a token: find out
  # whether it died of a suspension, so the person is told rather than
  # silently bounced to the sign-in page.
  defp reject_stale_session(conn) do
    case conn.private[:session_token_before_load] || get_session(conn, :user_token) do
      token when is_binary(token) ->
        case user_behind(token) do
          %User{suspended_at: %DateTime{}} = user -> sign_out(conn, user)
          _ -> delete_session(conn, :user_token)
        end

      _ ->
        conn
    end
  end

  # `AshAuthentication.Jwt.verify/2` refuses a revoked token outright, so
  # check the signature alone: a forged subject earns nothing here but a
  # cleared session, and the lookup confirms the account is suspended.
  defp user_behind(token) do
    signer = JwtConfig.token_signer(User, [], %{})

    with {:ok, %{"sub" => subject}} <- Joken.verify(token, signer),
         {:ok, %User{} = user} <- AshAuthentication.subject_to_user(subject, User) do
      user
    else
      _ -> nil
    end
  end

  defp sign_out(conn, _user) do
    conn
    |> HuddlzWeb.BrowserSession.finalize_impersonation()
    |> clear_session()
    |> assign(:current_user, nil)
    |> redirect(to: ~p"/account-suspended?signed_out=1")
    |> halt()
  end

  defp revoke(token) when is_binary(token), do: Tokens.revoke(Token, token)
  defp revoke(_token), do: :ok
end
