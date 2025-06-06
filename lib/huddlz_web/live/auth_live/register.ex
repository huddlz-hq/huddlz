defmodule HuddlzWeb.AuthLive.Register do
  use HuddlzWeb, :live_view

  alias AshPhoenix.Form
  alias Huddlz.Accounts.User
  import HuddlzWeb.Layouts

  @impl true
  def mount(_params, _session, socket) do
    form =
      User
      |> Form.for_create(:register_with_password,
        as: "user"
      )

    {:ok,
     socket
     |> assign(check_errors: false)
     |> assign_form(form)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.app flash={@flash} current_user={assigns[:current_user]}>
      <div class="mx-auto max-w-md">
        <div class="card bg-base-100 shadow-xl">
          <div class="card-body">
            <h2 class="card-title text-center text-2xl font-bold">Create your account</h2>

            <.form
              for={@form}
              id="registration-form"
              phx-change="validate"
              phx-submit="register"
              class="space-y-4"
            >
              <.input
                field={@form[:email]}
                type="email"
                label="Email"
                placeholder="you@example.com"
                required
                autocomplete="email"
              />

              <div>
                <.input
                  field={@form[:password]}
                  type="password"
                  label="Password"
                  placeholder="At least 8 characters"
                  required
                  autocomplete="new-password"
                  phx-debounce="blur"
                />
                <div class="mt-1 text-sm text-base-content/70">
                  <p>Password must be at least 8 characters long</p>
                </div>
              </div>

              <.input
                field={@form[:password_confirmation]}
                type="password"
                label="Confirm Password"
                placeholder="Type your password again"
                required
                autocomplete="new-password"
                phx-debounce="blur"
              />

              <.button type="submit" phx-disable-with="Creating account..." class="btn-primary w-full">
                Create account
              </.button>
            </.form>

            <div class="divider">OR</div>

            <div class="text-center">
              <p class="text-base-content/70">
                Already have an account?
                <.link navigate="/sign-in" class="link link-primary">
                  Sign in
                </.link>
              </p>
            </div>
          </div>
        </div>
      </div>
    </.app>
    """
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
      redirect(socket, to: "/auth/user/password/sign_in?token=#{token}")
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
