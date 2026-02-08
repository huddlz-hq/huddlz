defmodule HuddlzWeb.AuthLive.SignIn do
  @moduledoc """
  LiveView for user sign-in with email and password authentication.
  """
  use HuddlzWeb, :live_view

  alias AshPhoenix.Form
  alias Huddlz.Accounts.User
  import HuddlzWeb.Layouts

  @impl true
  def render(assigns) do
    ~H"""
    <.app flash={@flash} current_user={assigns[:current_user]}>
      <div class="mx-auto max-w-md">
        <h1 class="font-display text-2xl tracking-tight text-center">Sign in to your account</h1>
        <p class="text-center text-base-content/40 mt-2">Welcome back!</p>

        <%!-- Password Sign In Form --%>
        <div class="border border-base-300 p-6 mt-8">
          <h2 class="font-display text-xl mb-4">Sign in with password</h2>

          <.form
            :let={f}
            for={@password_form}
            id="password-sign-in-form"
            phx-submit="sign_in_with_password"
            phx-change="validate_password"
            phx-trigger-action={@trigger_action}
            action="/auth/user/password/sign_in"
            method="post"
          >
            <.input field={f[:email]} type="email" label="Email" autocomplete="email" />
            <.input
              field={f[:password]}
              type="password"
              label="Password"
              autocomplete="current-password"
            />

            <div class="mt-6">
              <.button phx-disable-with="Signing in..." class="w-full">
                Sign in
              </.button>
            </div>
          </.form>

          <div class="text-sm mt-4">
            <a href="/reset" class="text-primary hover:underline font-medium">
              Forgot your password?
            </a>
          </div>
        </div>

        <div class="text-center mt-8">
          <span class="text-sm text-base-content/50">
            Don't have an account?
          </span>
          <a href="/register" class="text-primary hover:underline font-medium text-sm ml-1">
            Sign up
          </a>
        </div>
      </div>
    </.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    # Get the password strategy to pass proper context
    strategy = AshAuthentication.Info.strategy!(User, :password)

    # Build context like the default Ash auth does
    context = %{
      strategy: strategy,
      private: %{ash_authentication?: true}
    }

    # Add token_type if sign_in_tokens are enabled
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
     |> assign(:page_title, "Sign In")
     |> assign(:password_form, password_form)
     |> assign(:trigger_action, false)}
  end

  @impl true
  def handle_event("sign_in_with_password", %{"user" => params}, socket) do
    # Match Ash's sign-in form behavior exactly
    strategy = AshAuthentication.Info.strategy!(User, :password)

    if Map.get(strategy, :sign_in_tokens_enabled?) do
      # Token-based sign in (Ash's default behavior)
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
      # Direct form submission with phx-trigger-action
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
