defmodule HuddlzWeb.AuthLive.ResetPasswordConfirm do
  use HuddlzWeb, :live_view
  alias AshPhoenix.Form
  alias Huddlz.Accounts.User

  import HuddlzWeb.Layouts

  @impl true
  def mount(%{"token" => token}, _session, socket) do
    # Create form for reset_password_with_token action with token pre-filled
    form =
      Form.for_action(User, :reset_password_with_token, params: %{"reset_token" => token})

    {:ok,
     socket
     |> assign(:form, to_form(form))
     |> assign(:token, token)
     |> assign(:token_valid, true)}
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
                for={@form}
                phx-change="validate"
                phx-submit="reset_password"
                id="reset-password-confirm-form"
              >
                <.input field={@form[:password]} type="password" label="New password" required />

                <.input
                  field={@form[:password_confirmation]}
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
  def handle_event("validate", %{"form" => params}, socket) do
    form = socket.assigns.form.source |> Form.validate(params)
    {:noreply, assign(socket, form: to_form(form))}
  end

  def handle_event("reset_password", %{"form" => params}, socket) do
    form = socket.assigns.form.source |> Form.validate(params)

    if form.valid? do
      handle_valid_reset_form(socket, form, params)
    else
      {:noreply, assign(socket, form: to_form(form))}
    end
  end

  defp handle_valid_reset_form(socket, form, params) do
    case Form.submit(form, params: params) do
      {:ok, result} ->
        # Password reset successful, sign them in with the token
        token = result.__metadata__.token

        {:noreply,
         socket
         |> redirect(to: "/auth/user/password/sign_in_with_token?token=#{token}")}

      {:error, form} ->
        handle_reset_error(socket, form)
    end
  end

  defp handle_reset_error(socket, form) do
    errors = Form.errors(form)

    if Keyword.has_key?(errors, :reset_token) do
      {:noreply, assign(socket, :token_valid, false)}
    else
      {:noreply, assign(socket, form: to_form(form))}
    end
  end
end
