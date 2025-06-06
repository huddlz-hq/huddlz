defmodule HuddlzWeb.AuthLive.ResetPasswordConfirm do
  use HuddlzWeb, :live_view
  alias AshPhoenix.Form
  alias Huddlz.Accounts.User

  import HuddlzWeb.Layouts

  @impl true
  def mount(%{"token" => token}, _session, socket) do
    # Get the password strategy for proper context
    strategy = AshAuthentication.Info.strategy!(User, :password)
    domain = AshAuthentication.Info.authentication_domain!(User)

    # Create form for reset_password_with_token action with token pre-filled
    form =
      Form.for_action(User, :reset_password_with_token,
        params: %{"reset_token" => token},
        domain: domain,
        as: "user",
        id: "user-password-reset_password_with_token",
        context: %{strategy: strategy, private: %{ash_authentication?: true}}
      )

    {:ok,
     socket
     |> assign(:form, to_form(form))
     |> assign(:token, token)
     |> assign(:token_valid, true)
     |> assign(:trigger_action, false)}
  end

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:token_valid, false)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.app flash={@flash} current_user={assigns[:current_user]}>
      <div class="max-w-md mx-auto">
        <div class="card bg-base-100 shadow-xl">
          <div class="card-body">
            <%= if @token_valid do %>
              <h2 class="card-title text-2xl mb-4">Set new password</h2>

              <.form
                :let={f}
                for={@form}
                phx-change="validate"
                phx-submit="reset_password"
                phx-trigger-action={if @trigger_action, do: "true", else: "false"}
                action="/auth/user/password/reset"
                method="post"
                id="reset-password-confirm-form"
              >
                <input type="hidden" name="user[reset_token]" value={@token} />

                <.input field={f[:password]} type="password" label="New password" required />

                <.input
                  field={f[:password_confirmation]}
                  type="password"
                  label="Confirm new password"
                  required
                />

                <div class="text-xs text-gray-600 mt-1 mb-4">
                  Password must be at least 8 characters long
                </div>

                <div class="form-control mt-6">
                  <.button phx-disable-with="Resetting..." class="btn btn-primary">
                    Reset password
                  </.button>
                </div>
              </.form>
            <% else %>
              <h2 class="card-title text-2xl mb-4">Invalid reset link</h2>

              <div class="alert alert-error">
                <svg
                  xmlns="http://www.w3.org/2000/svg"
                  class="stroke-current shrink-0 h-6 w-6"
                  fill="none"
                  viewBox="0 0 24 24"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M10 14l2-2m0 0l2-2m-2 2l-2-2m2 2l2 2m7-2a9 9 0 11-18 0 9 9 0 0118 0z"
                  />
                </svg>
                <span>This password reset link is invalid or has expired.</span>
              </div>

              <div class="form-control mt-6">
                <.link navigate="/reset" class="btn btn-primary">
                  Request new reset link
                </.link>
              </div>
            <% end %>
          </div>
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

  def handle_event("reset_password", params, socket) do
    # Extract the user params from the form submission
    user_params = Map.get(params, "user", %{})

    # Add the reset token to the params if not present
    user_params = Map.put_new(user_params, "reset_token", socket.assigns.token)

    form = socket.assigns.form.source |> Form.validate(user_params)

    socket =
      socket
      |> assign(:form, to_form(form))
      |> assign(:trigger_action, form.valid?)

    {:noreply, socket}
  end
end
