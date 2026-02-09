defmodule HuddlzWeb.AuthLive.ResetPasswordConfirm do
  @moduledoc """
  LiveView for setting a new password using a reset token.
  """
  use HuddlzWeb, :live_view
  alias AshPhoenix.Form
  alias Huddlz.Accounts.User

  import HuddlzWeb.Layouts

  @impl true
  def mount(%{"token" => token}, _session, socket) do
    strategy = AshAuthentication.Info.strategy!(User, :password)
    domain = AshAuthentication.Info.authentication_domain!(User)

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
     |> assign(:token_valid, false)
     |> assign(:trigger_action, false)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.app flash={@flash} current_user={assigns[:current_user]}>
      <div class="max-w-md mx-auto">
        <div class="border border-base-300 p-6">
          <%= if @token_valid do %>
            <h2 class="font-display text-2xl tracking-tight mb-4">Set new password</h2>

            <.form
              :let={f}
              for={@form}
              phx-change="validate"
              phx-submit="reset_password"
              phx-trigger-action={@trigger_action}
              action="/auth/user/password/reset"
              method="POST"
              id="reset-password-confirm-form"
            >
              <input
                type="hidden"
                name={Phoenix.HTML.Form.input_name(f, :reset_token)}
                value={@token}
              />

              <%= if f[:reset_token].errors != [] do %>
                <div class="border border-error/30 p-4 bg-error/5 flex items-start gap-3 mb-4">
                  <.icon name="hero-x-circle" class="w-5 h-5 text-error flex-shrink-0 mt-0.5" />
                  <span class="text-sm">This password reset link is invalid or has expired.</span>
                </div>
                <div class="mt-4">
                  <.link
                    navigate="/reset"
                    class="block text-center text-primary hover:underline font-medium"
                  >
                    Request new reset link
                  </.link>
                </div>
              <% else %>
                <.input
                  field={f[:password]}
                  type="password"
                  label="New password"
                  autocomplete="new-password"
                />

                <.input
                  field={f[:password_confirmation]}
                  type="password"
                  label="Confirm new password"
                  autocomplete="new-password"
                />

                <div class="text-xs text-base-content/60 mt-1 mb-4">
                  Password must be at least 8 characters long
                </div>

                <div class="mt-6">
                  <.button phx-disable-with="Resetting..." class="w-full">
                    Reset password
                  </.button>
                </div>
              <% end %>
            </.form>
          <% else %>
            <h2 class="font-display text-2xl tracking-tight mb-4">Invalid reset link</h2>

            <div class="border border-error/30 p-4 bg-error/5 flex items-start gap-3">
              <.icon name="hero-x-circle" class="w-5 h-5 text-error flex-shrink-0 mt-0.5" />
              <span class="text-sm">This password reset link is invalid or has expired.</span>
            </div>

            <.link
              navigate="/reset"
              class="block text-center text-primary hover:underline font-medium mt-6"
            >
              Request new reset link
            </.link>
          <% end %>
        </div>
      </div>
    </.app>
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
