defmodule HuddlzWeb.AuthLive.MagicLinkSignIn do
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
          Complete Sign In
          <:subtitle>
            Click the button below to complete your sign in.
          </:subtitle>
        </.header>

        <div class="card bg-base-100 shadow-xl">
          <div class="card-body">
            <h2 class="card-title">Magic Link Sign In</h2>
            <p class="text-sm text-base-content/70">
              You've arrived here via a magic link. Click below to complete your sign in.
            </p>

            <.form
              :let={f}
              for={@form}
              action={@action_url}
              method="post"
              phx-submit="submit"
              phx-trigger-action={@trigger_action}
            >
              <input type="hidden" name={f[:token].name} value={@token} />

              <div class="mt-6">
                <.button type="submit" phx-disable-with="Signing in..." class="w-full">
                  Sign in
                </.button>
              </div>
            </.form>
          </div>
        </div>
      </div>
    </.app>
    """
  end

  @impl true
  def mount(_params, session, socket) do
    # Extract session data that magic_sign_in_route provides
    strategy = session["strategy"] || :magic_link
    resource = session["resource"] || User
    auth_routes_prefix = session["auth_routes_prefix"] || "/auth"
    overrides = session["overrides"] || []

    # Get the strategy configuration
    strategy_config = AshAuthentication.Info.strategy!(resource, strategy)

    # Build the form context
    context = %{
      strategy: strategy_config,
      private: %{ash_authentication?: true}
    }

    # Create the form for the sign_in_with_magic_link action
    form =
      resource
      |> Form.for_action(:sign_in_with_magic_link,
        as: "user",
        context: context,
        domain: Huddlz.Accounts
      )
      |> Form.validate(%{"token" => ""})
      |> to_form()

    # Build the action URL
    subject_name = to_string(resource) |> String.split(".") |> List.last() |> Macro.underscore()
    action_url = "#{auth_routes_prefix}/#{subject_name}/#{strategy}"

    {:ok,
     socket
     |> assign(:page_title, "Complete Sign In")
     |> assign(:form, form)
     |> assign(:trigger_action, false)
     |> assign(:token, "")
     |> assign(:strategy, strategy)
     |> assign(:resource, resource)
     |> assign(:auth_routes_prefix, auth_routes_prefix)
     |> assign(:action_url, action_url)
     |> assign(:overrides, overrides)
     |> assign_new(:current_user, fn -> nil end)}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    token = params["token"] || ""

    # Update the form with the token
    form =
      socket.assigns.resource
      |> Form.for_action(:sign_in_with_magic_link,
        as: "user",
        context: %{
          strategy:
            AshAuthentication.Info.strategy!(socket.assigns.resource, socket.assigns.strategy),
          private: %{ash_authentication?: true}
        },
        domain: Huddlz.Accounts
      )
      |> Form.validate(%{"token" => token})
      |> to_form()

    {:noreply,
     socket
     |> assign(:token, token)
     |> assign(:form, form)}
  end

  @impl true
  def handle_event("submit", %{"user" => user_params}, socket) do
    form =
      socket.assigns.form.source
      |> Form.validate(user_params)
      |> to_form()

    socket =
      socket
      |> assign(:form, form)
      |> assign(:trigger_action, form.source.valid?)

    {:noreply, socket}
  end
end
