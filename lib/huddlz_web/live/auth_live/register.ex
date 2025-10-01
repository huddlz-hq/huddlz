defmodule HuddlzWeb.AuthLive.Register do
  use HuddlzWeb, :live_view

  alias AshPhoenix.Form
  alias Huddlz.Accounts.DisplayNameGenerator
  alias Huddlz.Accounts.User
  import HuddlzWeb.Layouts
  require Ash

  @impl true
  def mount(_params, _session, socket) do
    # Get the password strategy to pass proper context
    strategy = AshAuthentication.Info.strategy!(User, :password)

    # Build context like the default Ash auth does
    context = %{
      strategy: strategy,
      private: %{ash_authentication?: true}
    }

    # Add token_type if sign_in_tokens are enabled for registration
    context =
      if Map.get(strategy, :sign_in_tokens_enabled?) do
        Map.put(context, :token_type, :sign_in)
      else
        context
      end

    password_form =
      User
      |> Form.for_create(:register_with_password,
        as: "user",
        context: context
      )

    {:ok,
     socket
     |> assign(check_errors: false)
     |> assign_form(password_form)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.app flash={@flash} current_user={assigns[:current_user]}>
      <div class="mx-auto max-w-md">
        <.header class="text-center">
          Create your account
          <:subtitle>
            Sign up to start creating and joining huddlz
          </:subtitle>
        </.header>

        <%!-- Password Registration Form --%>
        <div class="card bg-base-100 shadow-xl">
          <div class="card-body">
            <h2 class="card-title">Sign up with password</h2>

            <.form for={@form} id="registration-form" phx-change="validate" phx-submit="register">
              <.input
                field={@form[:email]}
                type="text"
                label="Email"
                placeholder="you@example.com"
                autocomplete="email"
              />

              <div>
                <.input
                  field={@form[:display_name]}
                  type="text"
                  label="Display Name"
                  placeholder="First and Last Name"
                  autocomplete="name"
                />
                <button
                  type="button"
                  phx-click="generate_display_name"
                  class="btn btn-ghost btn-sm mt-1"
                >
                  <.icon name="hero-arrow-path" class="h-4 w-4" /> Generate Random Name
                </button>
              </div>

              <div>
                <.input
                  field={@form[:password]}
                  type="password"
                  label="Password"
                  placeholder="At least 8 characters"
                  autocomplete="new-password"
                  phx-debounce="blur"
                />
                <div class="text-xs text-gray-600 mt-1 mb-4">
                  Password must be at least 8 characters long
                </div>
              </div>

              <.input
                field={@form[:password_confirmation]}
                type="password"
                label="Confirm Password"
                placeholder="Type your password again"
                autocomplete="new-password"
                phx-debounce="blur"
              />

              <div class="mt-6">
                <.button type="submit" phx-disable-with="Creating account..." class="w-full">
                  Create account
                </.button>
              </div>
            </.form>
          </div>
        </div>

        <div class="text-center mt-8">
          <span class="text-sm text-base-content/70">
            Already have an account?
          </span>
          <a href="/sign-in" class="link link-primary text-sm ml-1">
            Sign in
          </a>
        </div>
      </div>
    </.app>
    """
  end

  @impl true
  def handle_event("generate_display_name", _params, socket) do
    # Generate a new random display name
    new_display_name = DisplayNameGenerator.generate()

    # Get current form params and update display_name
    current_params = Form.params(socket.assigns.form.source)
    updated_params = Map.put(current_params, "display_name", new_display_name)

    # Validate the form with the new display_name
    form =
      socket.assigns.form.source
      |> Form.validate(updated_params)

    {:noreply, assign_form(socket, form)}
  end

  @impl true
  def handle_event("validate", %{"user" => params}, socket) do
    form =
      socket.assigns.form.source
      |> Form.validate(params)

    {:noreply,
     socket
     |> assign(check_errors: true)
     |> assign_form(form)}
  end

  @impl true
  def handle_event("register", %{"user" => params}, socket) do
    form =
      socket.assigns.form.source
      |> Form.validate(params)

    socket =
      if form.valid? do
        handle_form_submission(socket, form)
      else
        socket
        |> assign(check_errors: true)
        |> assign_form(form)
      end

    {:noreply, socket}
  end

  defp handle_form_submission(socket, form) do
    case Form.submit(form, params: nil) do
      {:ok, result} ->
        handle_successful_registration(socket, result)

      {:error, form} ->
        socket
        |> assign(check_errors: true)
        |> assign_form(form)
        |> put_flash(:error, get_form_errors(form))
    end
  end

  defp handle_successful_registration(socket, result) do
    # Get the token from the metadata
    token = result.__metadata__.token

    if token do
      # Redirect to the sign-in URL with the token
      redirect(socket, to: "/auth/user/password/sign_in_with_token?token=#{token}")
    else
      socket
      |> put_flash(
        :error,
        "Registration succeeded but automatic sign-in failed. Please sign in manually."
      )
      |> redirect(to: "/sign-in")
    end
  end

  defp assign_form(socket, form) do
    assign(socket, :form, to_form(form))
  end

  defp get_form_errors(form) do
    errors = Form.errors(form)

    if Enum.any?(errors) do
      Enum.map_join(errors, ", ", fn {field, message} ->
        "#{Phoenix.Naming.humanize(field)}: #{message}"
      end)
    else
      "Registration failed. Please check your inputs and try again."
    end
  end
end
