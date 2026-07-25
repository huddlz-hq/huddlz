defmodule HuddlzWeb.AuthLive.SignIn do
  @moduledoc """
  Sign-in page at `/sign-in`. Email + password only. Mounted under the v3
  auth shell — chromeless, no sidebar, no global topbar.
  """
  use HuddlzWeb, :live_view

  alias AshPhoenix.Form
  alias Huddlz.Accounts.User
  alias HuddlzWeb.AuthReturnTo

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.auth_shell flash={@flash}>
      <h1>Sign in</h1>
      <p class="lede">Welcome back. Sign in to RSVP, organize, and follow your groups.</p>

      <.form
        :let={f}
        for={@password_form}
        id="password-sign-in-form"
        phx-submit="sign_in_with_password"
        phx-change="validate_password"
        phx-trigger-action={@trigger_action}
        action={sign_in_path(@return_to)}
        method="post"
        class="auth-card"
      >
        <.error_summary form={@password_form} />

        <div class="form-grid">
          <.input field={f[:email]} type="email" label="Email" autocomplete="email" />
          <.input
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
        Don't have an account? <.link navigate={register_path(@return_to)}>Sign up</.link>
      </div>
    </Layouts.auth_shell>
    """
  end

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
      |> Form.for_action(:sign_in_with_password,
        as: "user",
        actor: socket.assigns[:current_user],
        context: context
      )
      |> to_form()

    {:ok,
     socket
     |> assign(:page_title, "Sign in")
     |> assign(:body_class, "is-auth")
     |> assign(:password_form, password_form)
     |> assign(:return_to, AuthReturnTo.validate(params["return_to"]))
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
             to: sign_in_token_path(token, socket.assigns.return_to)
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

  defp sign_in_path(nil), do: "/auth/user/password/sign_in"

  defp sign_in_path(return_to) do
    "/auth/user/password/sign_in?" <> URI.encode_query(return_to: return_to)
  end

  defp sign_in_token_path(token, nil), do: "/auth/user/password/sign_in_with_token?token=#{token}"

  defp sign_in_token_path(token, return_to) do
    "/auth/user/password/sign_in_with_token?" <>
      URI.encode_query(token: token, return_to: return_to)
  end

  defp register_path(nil), do: ~p"/register"

  defp register_path(return_to), do: ~p"/register?#{[return_to: return_to]}"
end
