defmodule HuddlzWeb.AuthLive.ResetPassword do
  use HuddlzWeb, :live_view
  alias AshPhoenix.Form
  alias Huddlz.Accounts.User

  import HuddlzWeb.Layouts

  @impl true
  def mount(_params, _session, socket) do
    form = Form.for_action(User, :request_password_reset_token)

    {:ok,
     socket
     |> assign(:form, to_form(form))
     |> assign(:submitted, false)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.app flash={@flash} current_user={assigns[:current_user]}>
      <div class="max-w-md mx-auto">
        <div class="card bg-base-100 shadow-xl">
          <div class="card-body">
            <h2 class="card-title text-2xl mb-4">Reset your password</h2>

            <%= if @submitted do %>
              <div class="alert alert-success">
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
                    d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"
                  />
                </svg>
                <span>
                  If an account exists for that email, you will receive password reset instructions shortly.
                </span>
              </div>

              <div class="form-control mt-6">
                <.link navigate="/sign-in" class="btn btn-ghost">
                  Back to sign in
                </.link>
              </div>
            <% else %>
              <p class="text-sm mb-6">
                Enter your email address and we'll send you instructions to reset your password.
              </p>

              <.form
                for={@form}
                phx-change="validate"
                phx-submit="request_reset"
                id="reset-password-form"
              >
                <.input
                  field={@form[:email]}
                  type="email"
                  label="Email"
                  placeholder="you@example.com"
                  required
                />

                <div class="form-control mt-6">
                  <.button phx-disable-with="Sending..." class="btn btn-primary">
                    Send reset instructions
                  </.button>
                </div>
              </.form>

              <div class="divider">or</div>

              <div class="text-center">
                <span class="text-sm">Remember your password? </span>
                <.link navigate="/sign-in" class="link link-primary text-sm">
                  Sign in
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

  def handle_event("request_reset", %{"form" => params}, socket) do
    form = socket.assigns.form.source |> Form.validate(params)

    case Form.submit(form, params: params) do
      :ok ->
        # Always show success message for security (don't reveal if email exists)
        {:noreply, assign(socket, :submitted, true)}

      {:ok, _} ->
        # Also handle the {:ok, result} case
        {:noreply, assign(socket, :submitted, true)}

      {:error, form} ->
        # This shouldn't happen as the action always succeeds
        {:noreply, assign(socket, form: to_form(form))}
    end
  end
end
