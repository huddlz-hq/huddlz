defmodule HuddlzWeb.AuthLive.ResetPasswordConfirm do
  @moduledoc """
  Reset-confirm page at `/reset/:token`. Renders either the new-password form
  (when the token is valid) or an expired-link state (when it isn't).
  """
  use HuddlzWeb, :live_view

  alias AshPhoenix.Form
  alias Huddlz.Accounts.User

  @impl true
  def mount(%{"token" => token}, _session, socket) do
    strategy = AshAuthentication.Info.strategy!(User, :password)
    domain = AshAuthentication.Info.authentication_domain!(User)

    socket =
      socket
      |> assign(:page_title, "Set new password")
      |> assign(:body_class, "v3 is-auth")

    with {:ok, %{"sub" => subject}, _resource} <- AshAuthentication.Jwt.verify(token, User),
         {:ok, user} <- AshAuthentication.subject_to_user(subject, User) do
      form =
        Form.for_update(user, :reset_password_with_token,
          params: %{"reset_token" => token},
          domain: domain,
          as: "user",
          id: "user-password-reset-password-with-token",
          context: %{strategy: strategy, private: %{ash_authentication?: true}}
        )

      {:ok,
       socket
       |> assign(:form, to_form(form))
       |> assign(:token, token)
       |> assign(:token_valid, true)
       |> assign(:trigger_action, false)}
    else
      _ ->
        {:ok, assign(socket, token_valid: false, trigger_action: false)}
    end
  end

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Set new password")
     |> assign(:body_class, "v3 is-auth")
     |> assign(:token_valid, false)
     |> assign(:trigger_action, false)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.auth_shell flash={@flash}>
      <%= if @token_valid do %>
        <h1>Set a new password</h1>
        <p class="lede">Almost there. Pick a new password and you'll be signed in.</p>

        <.form
          :let={f}
          for={@form}
          phx-change="validate"
          phx-submit="reset_password"
          phx-trigger-action={@trigger_action}
          action="/auth/user/password/reset"
          method="POST"
          id="reset-password-confirm-form"
          class="auth-card"
        >
          <input
            type="hidden"
            name={Phoenix.HTML.Form.input_name(f, :reset_token)}
            value={@token}
          />

          <%= if f[:reset_token].errors != [] do %>
            <.expired_token_state />
          <% else %>
            <div class="form-grid">
              <.v3_input
                field={f[:password]}
                type="password"
                label="New password"
                autocomplete="new-password"
                help="At least 8 characters."
              />
              <.v3_input
                field={f[:password_confirmation]}
                type="password"
                label="Confirm new password"
                autocomplete="new-password"
              />
            </div>
            <div class="form-foot">
              <button type="submit" class="btn-primary" phx-disable-with="Resetting...">
                Reset password
              </button>
            </div>
          <% end %>
        </.form>
      <% else %>
        <.expired_token_state />
      <% end %>
    </Layouts.auth_shell>
    """
  end

  defp expired_token_state(assigns) do
    ~H"""
    <div class="auth-state warn">
      <div class="icon-mark">
        <Layouts.auth_state_icon name="warn" />
      </div>
      <h2>This password reset link is invalid or has expired</h2>
      <p>The link may have expired or already been used. Request a fresh one.</p>
      <.link navigate={~p"/reset"} class="btn-primary">Request new reset link</.link>
    </div>
    """
  end

  @impl true
  def handle_event("validate", %{"user" => params}, socket) do
    form = socket.assigns.form.source |> Form.validate(params, errors: false)
    {:noreply, assign(socket, form: to_form(form))}
  end

  def handle_event("reset_password", %{"user" => params}, socket) do
    params = Map.put_new(params, "reset_token", socket.assigns.token)
    form = socket.assigns.form.source |> Form.validate(params)

    socket =
      socket
      |> assign(:form, to_form(form))
      |> assign(:trigger_action, form.valid?)

    {:noreply, socket}
  end
end
