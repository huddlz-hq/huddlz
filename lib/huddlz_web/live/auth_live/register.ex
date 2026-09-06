defmodule HuddlzWeb.AuthLive.Register do
  @moduledoc """
  Registration page at `/register`. Email + display name + password. Mounted
  under the v3 auth shell — chromeless, no sidebar, no global topbar.
  """
  use HuddlzWeb, :live_view

  alias AshPhoenix.Form
  alias Huddlz.Accounts.DisplayNameGenerator
  alias Huddlz.Accounts.User
  alias Huddlz.Legal
  alias HuddlzWeb.AuthFormErrors
  alias HuddlzWeb.AuthReturnTo

  @impl true
  def mount(params, _session, socket) do
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
        context: context,
        post_process_errors: &AuthFormErrors.post_process/3
      )

    {:ok,
     socket
     |> assign(:page_title, "Create account")
     |> assign(:body_class, "is-auth")
     |> assign(:check_errors, false)
     |> assign(:return_to, AuthReturnTo.validate(params["return_to"]))
     |> assign_form(password_form)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.auth_shell flash={@flash}>
      <h1>Create your account</h1>
      <p class="lede">Names aren't unique on huddlz — pick anything you like.</p>

      <.form
        for={@form}
        id="registration-form"
        phx-change="validate"
        phx-submit="register"
        novalidate
        class="auth-card"
      >
        <div class="form-grid">
          <.input
            field={@form[:email]}
            type="email"
            label="Email"
            placeholder="you@example.com"
            autocomplete="email"
          />

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
            class="btn-secondary auth-aux-btn"
          >
            Generate random name
          </button>

          <.input
            field={@form[:password]}
            type="password"
            label="Password"
            placeholder="At least 8 characters"
            autocomplete="new-password"
            help="At least 8 characters."
            phx-debounce="blur"
          />

          <.input
            field={@form[:password_confirmation]}
            type="password"
            label="Confirm Password"
            placeholder="Type your password again"
            autocomplete="new-password"
            phx-debounce="blur"
          />

          <div class="legal-acceptance">
            <input type="hidden" name={@form[:legal_acceptance].name} value="false" />
            <label class="legal-acceptance-control" for={@form[:legal_acceptance].id}>
              <input
                type="checkbox"
                id={@form[:legal_acceptance].id}
                name={@form[:legal_acceptance].name}
                value="true"
                checked={
                  Phoenix.HTML.Form.normalize_value(
                    "checkbox",
                    @form[:legal_acceptance].value
                  )
                }
              />
              <span>{Legal.acceptance_text()}</span>
            </label>
            <p class="legal-acceptance-links">
              Read the <a href={~p"/terms"} target="_blank" rel="noopener">Terms of Service</a>, <a
                href={~p"/code-of-conduct"}
                target="_blank"
                rel="noopener"
              >Code of Conduct</a>, and <a href={~p"/privacy"} target="_blank" rel="noopener">Privacy Policy</a>.
              Each opens in a new tab.
            </p>
            <.field_errors field={@form[:legal_acceptance]} />
          </div>
        </div>
        <div class="form-foot">
          <button type="submit" class="btn-primary" phx-disable-with="Creating account...">
            Create account
          </button>
        </div>
      </.form>

      <div class="auth-aside">
        Already have an account? <.link navigate={sign_in_path(@return_to)}>Sign in</.link>
      </div>
    </Layouts.auth_shell>
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
      redirect(socket, to: sign_in_token_path(token, socket.assigns.return_to))
    else
      socket
      |> put_flash(
        :error,
        "Registration succeeded but automatic sign-in failed. Please sign in manually."
      )
      |> redirect(to: sign_in_path(socket.assigns.return_to))
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

  defp sign_in_path(nil), do: ~p"/sign-in"

  defp sign_in_path(return_to), do: ~p"/sign-in?#{[return_to: return_to]}"

  defp sign_in_token_path(token, nil), do: "/auth/user/password/sign_in_with_token?token=#{token}"

  defp sign_in_token_path(token, return_to) do
    "/auth/user/password/sign_in_with_token?" <>
      URI.encode_query(token: token, return_to: return_to)
  end
end
