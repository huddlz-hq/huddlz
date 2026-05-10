defmodule HuddlzWeb.AuthLive.SignIn do
  @moduledoc """
  Sign-in page at `/sign-in`. Email + password only. Mounted under the v3
  auth shell — chromeless, no sidebar, no global topbar.
  """
  use HuddlzWeb, :live_view

  alias AshPhoenix.Form
  alias Huddlz.Accounts.User

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
        <h1>Sign in</h1>
        <p class="lede">Welcome back. Sign in to RSVP, organize, and follow your groups.</p>

        <.form
          :let={f}
          for={@password_form}
          id="password-sign-in-form"
          phx-submit="sign_in_with_password"
          phx-change="validate_password"
          phx-trigger-action={@trigger_action}
          action="/auth/user/password/sign_in"
          method="post"
          class="auth-card"
        >
          <div class="form-grid">
            <.v3_input
              field={f[:email]}
              type="email"
              label="Email"
              autocomplete="email"
            />
            <.v3_input
              field={f[:password]}
              type="password"
              label="Password"
              autocomplete="current-password"
            />
          </div>
          <div class="form-foot">
            <button type="submit" class="btn-primary" phx-disable-with="Signing in...">
              Sign in
            </button>
          </div>
        </.form>

        <div class="auth-aside">
          <.link navigate={~p"/reset"}>Forgot your password?</.link>
        </div>
        <div class="auth-aside">
          Don't have an account? <.link navigate={~p"/register"}>Sign up</.link>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    strategy = AshAuthentication.Info.strategy!(User, :password)

    context = %{
      strategy: strategy,
      private: %{ash_authentication?: true}
    }

    context =
      if Map.get(strategy, :sign_in_tokens_enabled?) do
        Map.put(context, :token_type, :sign_in)
      else
        context
      end

    password_form =
      User
      |> Form.for_action(:sign_in_with_password,
        as: "user",
        actor: socket.assigns[:current_user],
        context: context
      )
      |> to_form()

    {:ok,
     socket
     |> assign(:page_title, "Sign in")
     |> assign(:body_class, "v3 is-auth")
     |> assign(:password_form, password_form)
     |> assign(:trigger_action, false)}
  end

  @impl true
  def handle_event("sign_in_with_password", %{"user" => params}, socket) do
    strategy = AshAuthentication.Info.strategy!(User, :password)

    if Map.get(strategy, :sign_in_tokens_enabled?) do
      case Form.submit(socket.assigns.password_form.source, params: params, read_one?: true) do
        {:ok, user} ->
          token = user.__metadata__.token

          {:noreply,
           redirect(socket,
             to: "/auth/user/password/sign_in_with_token?token=#{token}"
           )}

        {:error, form} ->
          {:noreply,
           socket
           |> put_flash(:error, "Incorrect email or password")
           |> assign(
             :password_form,
             to_form(Form.clear_value(form, :password))
           )}
      end
    else
      form =
        socket.assigns.password_form.source
        |> Form.validate(params)
        |> to_form()

      socket =
        socket
        |> assign(:password_form, form)
        |> assign(:trigger_action, form.source.valid?)

      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("validate_password", %{"user" => params}, socket) do
    form =
      socket.assigns.password_form.source
      |> Form.validate(params, errors: true)
      |> to_form()

    {:noreply, assign(socket, :password_form, form)}
  end
end
