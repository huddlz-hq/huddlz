defmodule HuddlzWeb.AuthLive.Register do
  @moduledoc """
  Registration page at `/register`. Email + display name + password. Mounted
  under the v3 auth shell — chromeless, no sidebar, no global topbar.
  """
  use HuddlzWeb, :live_view

  alias AshPhoenix.Form
  alias Huddlz.Accounts.DisplayNameGenerator
  alias Huddlz.Accounts.User
  require Ash

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
      |> Form.for_create(:register_with_password,
        as: "user",
        context: context
      )

    {:ok,
     socket
     |> assign(:page_title, "Create account")
     |> assign(:body_class, "v3 is-auth")
     |> assign(:check_errors, false)
     |> assign_form(password_form)}
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
        <h1>Create your account</h1>
        <p class="lede">Names aren't unique on huddlz — pick anything you like.</p>

        <.form
          for={@form}
          id="registration-form"
          phx-change="validate"
          phx-submit="register"
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

            <div class="form-row">
              <label for="user_display_name" class="form-label">Display Name</label>
              <input
                type="text"
                id="user_display_name"
                name="user[display_name]"
                value={Phoenix.HTML.Form.normalize_value("text", @form[:display_name].value)}
                class="form-input"
                placeholder="First and Last Name"
                autocomplete="name"
              />
              <button
                type="button"
                phx-click="generate_display_name"
                class="btn-secondary"
                style="margin-top:6px;align-self:flex-start;height:32px;padding:0 12px;font-size:12px"
              >
                Generate random name
              </button>
              <p :for={msg <- field_errors(@form[:display_name])} class="form-error">{msg}</p>
            </div>

            <.v3_input
              field={@form[:password]}
              type="password"
              label="Password"
              placeholder="At least 8 characters"
              autocomplete="new-password"
              help="At least 8 characters."
              phx-debounce="blur"
            />

            <.v3_input
              field={@form[:password_confirmation]}
              type="password"
              label="Confirm Password"
              placeholder="Type your password again"
              autocomplete="new-password"
              phx-debounce="blur"
            />
          </div>
          <div class="form-foot">
            <button type="submit" class="btn-primary" phx-disable-with="Creating account...">
              Create account
            </button>
          </div>
        </.form>

        <div class="auth-aside">
          Already have an account? <.link navigate={~p"/sign-in"}>Sign in</.link>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("generate_display_name", _params, socket) do
    new_display_name = DisplayNameGenerator.generate()
    current_params = Form.params(socket.assigns.form.source)
    updated_params = Map.put(current_params, "display_name", new_display_name)

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
    token = result.__metadata__.token

    if token do
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

  defp field_errors(field) do
    if Phoenix.Component.used_input?(field) do
      Enum.map(field.errors, &translate_field_error/1)
    else
      []
    end
  end

  defp translate_field_error({msg, opts}) do
    Enum.reduce(opts, msg, fn {key, value}, acc ->
      String.replace(acc, "%{#{key}}", fn _ -> to_string(value) end)
    end)
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
