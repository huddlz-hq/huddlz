defmodule HuddlzWeb.AuthController do
  use HuddlzWeb, :controller
  use AshAuthentication.Phoenix.Controller

  alias AshAuthentication.TokenResource.Actions, as: Tokens
  alias Huddlz.Accounts.ConfirmationDestination
  alias Huddlz.Accounts.Token
  alias Huddlz.Accounts.User
  alias Huddlz.Accounts.User.Errors.ConfirmationAddressChanged
  alias HuddlzWeb.AuthReturnTo
  alias HuddlzWeb.BrowserSession

  # A suspended account can prove a password or an address, but neither
  # lifts the suspension: the token just minted is revoked and no session
  # is stored.
  def success(conn, _activity, %User{suspended_at: %DateTime{}}, token) do
    if is_binary(token), do: Tokens.revoke(Token, token)

    conn
    |> BrowserSession.finalize_impersonation()
    |> clear_session(:huddlz)
    |> redirect(to: ~p"/account-suspended")
  end

  def success(conn, activity, user, _token) do
    return_to =
      if activity == {:confirm_new_user, :confirm} do
        ConfirmationDestination.validate(user.__metadata__[:confirmation_destination]) || ~p"/"
      else
        return_to(conn)
      end

    ConfirmationDestination.remember(user, return_to)

    return_to = intent_destination(user, return_to)

    message =
      case activity do
        {:confirm_new_user, :confirm} ->
          "Your email address has now been confirmed"

        {:password, :reset} ->
          "Your password has successfully been reset"

        {:magic_link, :sign_in} ->
          "You are now signed in"

        _ ->
          "You are now signed in"
      end

    conn
    |> BrowserSession.finalize_impersonation()
    |> BrowserSession.disconnect_live_views()
    |> delete_session(:return_to)
    |> store_in_session(user)
    |> put_live_socket_id()
    # If your resource has a different name, update the assign name here (i.e :current_admin)
    |> assign(:current_user, user)
    |> put_flash(:info, message)
    |> redirect(to: return_to)
  end

  def failure(conn, activity, reason) do
    message =
      case {activity, reason} do
        {_,
         %AshAuthentication.Errors.AuthenticationFailed{
           caused_by: %Ash.Error.Forbidden{
             errors: [%AshAuthentication.Errors.CannotConfirmUnconfirmedUser{}]
           }
         }} ->
          """
          You have already signed in another way, but have not confirmed your account.
          You can confirm your account using the link we sent to you, or by resetting your password.
          """

        {{:password, :reset}, _} ->
          "The password reset link is invalid or has expired. Please request a new one."

        {{:confirm_new_user, :confirm}, reason} ->
          if previous_address?(reason) do
            "That confirmation link was for a previous address. Confirm from the email sent to your current address."
          else
            "That confirmation link no longer works. If your email is confirmed, just sign in."
          end

        _ ->
          "Incorrect email or password"
      end

    conn
    |> put_flash(:error, message)
    |> redirect(to: ~p"/sign-in")
  end

  defp previous_address?(%ConfirmationAddressChanged{}), do: true

  defp previous_address?(%{errors: errors}) when is_list(errors),
    do: Enum.any?(errors, &previous_address?/1)

  defp previous_address?(_reason), do: false

  def sign_out(conn, _params) do
    return_to = return_to(conn)

    conn
    |> BrowserSession.finalize_impersonation()
    |> BrowserSession.disconnect_live_views()
    |> clear_session(:huddlz)
    |> put_flash(:info, "You are now signed out")
    |> redirect(to: return_to)
  end

  defp put_live_socket_id(conn) do
    case get_session(conn, :user_token) do
      token when is_binary(token) ->
        put_session(conn, :live_socket_id, BrowserSession.live_socket_id(token))

      _ ->
        conn
    end
  end

  defp return_to(conn) do
    [conn.params["return_to"], get_session(conn, :return_to)]
    |> Enum.find_value(&AuthReturnTo.validate/1)
    |> Kernel.||(~p"/")
  end

  # POC variant E. With an explicit return destination the app already knows
  # what the person came for, so it must not ask — that journey sails straight
  # through. `return_to/1` falls back to "/" only when neither the params nor
  # the session carried a valid destination, so that clause is exactly the
  # no-intent case; anything else wins outright and nothing is interposed.
  defp intent_destination(user, "/" = fallback) do
    AuthReturnTo.validate(intent_path(user)) || fallback
  end

  defp intent_destination(_user, return_to), do: return_to

  # Unanswered: ask. Answered once: go where they said, so the question is a
  # one-time cost rather than a toll on every sign-in.
  defp intent_path(%User{landing_choice: :unasked}), do: ~p"/welcome"
  defp intent_path(%User{landing_choice: :find_a_huddl}), do: ~p"/discover"
  defp intent_path(%User{landing_choice: :my_huddlz}), do: ~p"/agenda"
  defp intent_path(_user), do: nil
end
