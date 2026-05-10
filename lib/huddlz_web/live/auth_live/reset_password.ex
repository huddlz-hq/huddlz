defmodule HuddlzWeb.AuthLive.ResetPassword do
  @moduledoc """
  Reset-request page at `/reset`. Asks the user for an email address; emits
  the reset email if an account exists. Always shows the success state — we
  don't reveal whether the address is registered.
  """
  use HuddlzWeb, :live_view

  alias AshPhoenix.Form
  alias Huddlz.Accounts.User

  @impl true
  def mount(_params, _session, socket) do
    form = Form.for_action(User, :request_password_reset_token)

    {:ok,
     socket
     |> assign(:page_title, "Reset password")
     |> assign(:body_class, "v3 is-auth")
     |> assign(:form, to_form(form))
     |> assign(:submitted, false)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.flash_group flash={@flash} />

    <div class="auth-shell">
      <header class="auth-topbar">
        <a href={~p"/"} style="display:flex;align-items:center;gap:10px">
          <div class="brand-glyph">h</div>
          <div class="brand-text">huddlz</div>
        </a>
      </header>

      <div class="auth-frame">
        <%= if @submitted do %>
          <div class="auth-state">
            <div class="icon-mark">
              <svg
                width="22"
                height="22"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                stroke-width="2"
                stroke-linecap="round"
                stroke-linejoin="round"
              >
                <path d="M5 13l4 4L19 7" />
              </svg>
            </div>
            <h2>Check your email</h2>
            <p>
              If an account exists for that email, you will receive password reset instructions shortly.
            </p>
            <.link navigate={~p"/sign-in"} class="btn-primary">Back to sign in</.link>
          </div>
        <% else %>
          <h1>Reset your password</h1>
          <p class="lede">Enter your email and we'll send a link to set a new password.</p>

          <.form
            for={@form}
            id="reset-password-form"
            phx-change="validate"
            phx-submit="request_reset"
            class="auth-card"
          >
            <div class="form-grid">
              <.v3_input
                field={@form[:email]}
                type="email"
                label="Email"
                placeholder="you@example.com"
                autocomplete="email"
              />
            </div>
            <div class="form-foot">
              <button type="submit" class="btn-primary" phx-disable-with="Sending...">
                Send reset instructions
              </button>
            </div>
          </.form>

          <div class="auth-aside">
            <.link navigate={~p"/sign-in"}>Back to sign in</.link>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("validate", %{"form" => params}, socket) do
    form = socket.assigns.form.source |> Form.validate(params)
    {:noreply, assign(socket, form: to_form(form))}
  end

  def handle_event("request_reset", %{"form" => params}, socket) do
    _form = socket.assigns.form.source |> Form.validate(params)

    input = Ash.ActionInput.for_action(User, :request_password_reset_token, params)

    case Ash.run_action(input) do
      :ok ->
        {:noreply, assign(socket, :submitted, true)}

      {:error, _} ->
        {:noreply, assign(socket, :submitted, true)}
    end
  end
end
