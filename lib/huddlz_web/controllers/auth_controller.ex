defmodule HuddlzWeb.AuthController do
  use HuddlzWeb, :controller
  use AshAuthentication.Phoenix.Controller

  alias HuddlzWeb.AuthReturnTo

  def success(conn, activity, user, _token) do
    return_to = return_to(conn)

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

        _ ->
          "Incorrect email or password"
      end

    conn
    |> put_flash(:error, message)
    |> redirect(to: ~p"/sign-in")
  end

  def sign_out(conn, _params) do
    return_to = return_to(conn)

    conn
    |> disconnect_live_views()
    |> clear_session(:huddlz)
    |> put_flash(:info, "You are now signed out")
    |> redirect(to: return_to)
  end

  defp put_live_socket_id(conn) do
    case get_session(conn, :user_token) do
      token when is_binary(token) ->
        put_session(conn, :live_socket_id, live_socket_id(token))

      _ ->
        conn
    end
  end

  defp disconnect_live_views(conn) do
    case get_session(conn, :live_socket_id) do
      topic when is_binary(topic) ->
        HuddlzWeb.Endpoint.broadcast(topic, "disconnect", %{})
        conn

      _ ->
        conn
    end
  end

  defp live_socket_id(token), do: "users_sessions:#{Base.url_encode64(token)}"

  defp return_to(conn) do
    [conn.params["return_to"], get_session(conn, :return_to)]
    |> Enum.find_value(&AuthReturnTo.validate/1)
    |> Kernel.||(~p"/")
  end
end
