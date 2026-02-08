defmodule HuddlzWeb.AuthLive.ResetPassword do
  @moduledoc """
  LiveView for requesting a password reset token via email.
  """
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
        <div class="border border-base-300 p-6">
          <h2 class="font-display text-2xl tracking-tight mb-4">Reset your password</h2>

          <%= if @submitted do %>
            <div class="border border-success/30 p-4 bg-success/5 flex items-start gap-3">
              <.icon name="hero-check-circle" class="w-5 h-5 text-success flex-shrink-0 mt-0.5" />
              <span class="text-sm">
                If an account exists for that email, you will receive password reset instructions shortly.
              </span>
            </div>

            <.link
              navigate="/sign-in"
              class="block text-center text-primary hover:underline font-medium mt-6"
            >
              Back to sign in
            </.link>
          <% else %>
            <p class="text-sm mb-6 text-base-content/50">
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
                autocomplete="email"
              />

              <div class="mt-6">
                <.button phx-disable-with="Sending..." class="w-full">
                  Send reset instructions
                </.button>
              </div>
            </.form>

            <div class="text-center mt-6">
              <span class="text-sm text-base-content/50">Remember your password? </span>
              <.link navigate="/sign-in" class="text-primary hover:underline font-medium text-sm">
                Sign in
              </.link>
            </div>
          <% end %>
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
    _form = socket.assigns.form.source |> Form.validate(params)

    # Use Ash.run_action for this action type
    input = Ash.ActionInput.for_action(User, :request_password_reset_token, params)

    case Ash.run_action(input) do
      :ok ->
        # Always show success message for security (don't reveal if email exists)
        {:noreply, assign(socket, :submitted, true)}

      {:error, _} ->
        # Also show success for security (don't reveal if email exists)
        {:noreply, assign(socket, :submitted, true)}
    end
  end
end
