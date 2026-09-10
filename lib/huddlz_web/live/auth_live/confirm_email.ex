defmodule HuddlzWeb.AuthLive.ConfirmEmail do
  @moduledoc """
  The page a new account's confirmation email links to, at
  `/confirm_new_user/:token`. A huddlz page like the other auth pages:
  one button that posts the token to the confirmation strategy, or a
  clear word when the link has expired or was already used.

  Registration signs the person in before they confirm, so the page
  accepts a signed-in visitor as well as a signed-out one.
  """
  use HuddlzWeb, :live_view

  alias AshAuthentication.{Info, Jwt, TokenResource}
  alias Huddlz.Accounts.User

  @impl true
  def mount(%{"token" => token}, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Confirm your email")
     |> assign(:body_class, "is-auth")
     |> assign(:token, token)
     |> assign(:token_valid, usable?(token))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.auth_shell flash={@flash}>
      <%= if @token_valid do %>
        <h1>Confirm your email</h1>
        <p class="lede">
          One quick step and your account is ready: confirm that this address is yours.
        </p>

        <form
          action={~p"/auth/user/confirm_new_user"}
          method="post"
          id="confirm-email-form"
          class="auth-card"
        >
          <input type="hidden" name="_csrf_token" value={Plug.CSRFProtection.get_csrf_token()} />
          <input type="hidden" name="user[confirm]" value={@token} />
          <div class="form-foot">
            <button type="submit" class="btn-primary">Confirm my email</button>
          </div>
        </form>
      <% else %>
        <div class="auth-state warn">
          <div class="icon-mark">
            <Layouts.auth_state_icon name="warn" />
          </div>
          <h2>This confirmation link no longer works</h2>
          <p>It may have expired or already been used. If your email is confirmed, just sign in.</p>
          <.link navigate={~p"/sign-in"} class="btn-primary">Sign in</.link>
        </div>
      <% end %>
    </Layouts.auth_shell>
    """
  end

  # A token that verifies and has not been spent. Confirming revokes it,
  # so a second visit lands on the expired state. The strategy itself
  # still checks the token when the form is posted.
  defp usable?(token) do
    with {:ok, _claims, _resource} <- Jwt.verify(token, User),
         {:ok, token_resource} <- Info.authentication_tokens_token_resource(User) do
      not TokenResource.token_revoked?(token_resource, token)
    else
      _ -> false
    end
  end
end
