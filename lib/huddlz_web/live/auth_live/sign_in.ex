defmodule HuddlzWeb.AuthLive.SignIn do
  use HuddlzWeb, :live_view

  alias AshPhoenix.Form
  alias Huddlz.Accounts.User
  import HuddlzWeb.Layouts

  @impl true
  def render(assigns) do
    ~H"""
    <.app flash={@flash} current_user={assigns[:current_user]}>
      <div class="mx-auto max-w-md">
        <.header class="text-center">
          Sign in to your account
          <:subtitle>
            Welcome back! Please sign in to continue.
          </:subtitle>
        </.header>

        <%!-- Password Sign In Form --%>
        <div class="card bg-base-100 shadow-xl">
          <div class="card-body">
            <h2 class="card-title">Sign in with password</h2>

            <.form
              :let={f}
              for={@password_form}
              id="password-sign-in-form"
              phx-submit="sign_in_with_password"
              phx-change="validate_password"
              phx-trigger-action={@trigger_action}
              action={~p"/auth/user/password/sign_in"}
              method="post"
            >
              <.input field={f[:email]} type="email" label="Email" required />
              <.input field={f[:password]} type="password" label="Password" required />

              <div class="mt-6">
                <.button phx-disable-with="Signing in..." class="w-full">
                  Sign in
                </.button>
              </div>
            </.form>

            <div class="text-sm mt-4">
              <a href="/reset" class="link link-primary">
                Forgot your password?
              </a>
            </div>
          </div>
        </div>

        <div class="divider my-8">OR</div>

        <%!-- Magic Link Form --%>
        <div class="card bg-base-100 shadow-xl">
          <div class="card-body">
            <h2 class="card-title">Sign in with magic link</h2>
            <p class="text-sm text-base-content/70">
              We'll send you an email with a secure link to sign in.
            </p>

            <.form
              :let={f}
              for={@magic_link_form}
              id="magic-link-form"
              phx-submit="request_magic_link"
              phx-change="validate_magic_link"
            >
              <.input field={f[:email]} type="email" label="Email" required />

              <div class="mt-6">
                <.button phx-disable-with="Sending magic link..." class="w-full" variant="primary">
                  {if @magic_link_sent, do: "Magic link sent!", else: "Request magic link"}
                </.button>
              </div>
            </.form>
          </div>
        </div>

        <div class="text-center mt-8">
          <span class="text-sm text-base-content/70">
            Don't have an account?
          </span>
          <a href="/register" class="link link-primary text-sm ml-1">
            Sign up
          </a>
        </div>
      </div>
    </.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    password_form =
      User
      |> Form.for_action(:sign_in_with_password,
        as: "user",
        actor: socket.assigns[:current_user]
      )
      |> to_form()

    magic_link_form =
      User
      |> Form.for_action(:request_magic_link,
        as: "magic_link",
        actor: socket.assigns[:current_user]
      )
      |> to_form()

    {:ok,
     socket
     |> assign(:page_title, "Sign In")
     |> assign(:password_form, password_form)
     |> assign(:magic_link_form, magic_link_form)
     |> assign(:magic_link_sent, false)
     |> assign(:trigger_action, false)}
  end

  @impl true
  def handle_event("sign_in_with_password", %{"user" => params}, socket) do
    # Validate the form first
    form =
      socket.assigns.password_form.source
      |> Form.validate(params)
      |> to_form()

    if form.source.valid? do
      # The password form needs to be submitted to the auth controller
      # so we trigger the form action
      {:noreply,
       socket
       |> assign(:password_form, form)
       |> assign(:trigger_action, true)}
    else
      {:noreply, assign(socket, :password_form, form)}
    end
  end

  @impl true
  def handle_event("request_magic_link", %{"magic_link" => params}, socket) do
    email = params["email"] || ""

    # If email is empty, don't submit
    if email == "" do
      form =
        socket.assigns.magic_link_form.source
        |> Form.validate(params, errors: true)
        |> to_form()

      {:noreply, assign(socket, :magic_link_form, form)}
    else
      # Use Ash to run the action
      input = Ash.ActionInput.for_action(User, :request_magic_link, %{email: email})

      case Ash.run_action(input) do
        :ok ->
          # Always show success to prevent email enumeration
          {:noreply,
           socket
           |> assign(:magic_link_sent, true)
           |> put_flash(
             :info,
             "If this user exists in our database, you will be contacted with a sign-in link shortly."
           )}

        {:error, _} ->
          # Still show success for security
          {:noreply,
           socket
           |> assign(:magic_link_sent, true)
           |> put_flash(
             :info,
             "If this user exists in our database, you will be contacted with a sign-in link shortly."
           )}
      end
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

  @impl true
  def handle_event("validate_magic_link", %{"magic_link" => params}, socket) do
    form =
      socket.assigns.magic_link_form.source
      |> Form.validate(params, errors: true)
      |> to_form()

    {:noreply, assign(socket, :magic_link_form, form)}
  end
end
