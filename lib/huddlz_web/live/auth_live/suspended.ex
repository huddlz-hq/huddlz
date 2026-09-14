defmodule HuddlzWeb.AuthLive.Suspended do
  @moduledoc """
  Where a suspended account lands, at `/account-suspended`: a refused
  sign-in, a password reset or email confirmation that must not sign the
  person in, and an open page that was signed out when the suspension
  took effect (`?signed_out=1`).

  Says only what the person needs: that they cannot sign in, that public
  huddlz and groups are still open, and one way to reach a person.
  """
  use HuddlzWeb, :live_view

  on_mount {HuddlzWeb.LiveUserAuth, :app}

  @impl true
  def mount(params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Account suspended")
     |> assign(:body_class, "is-auth")
     |> assign(:signed_out?, params["signed_out"] == "1")
     |> assign(:support, elem(Huddlz.Mailer.from(), 1))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.auth_shell flash={@flash} current_user={@current_user}>
      <div class="auth-state warn" id="account-suspended">
        <div class="icon-mark">
          <Layouts.auth_state_icon name="warn" />
        </div>
        <%= if @signed_out? do %>
          <h2>You were signed out</h2>
          <p>
            This account is suspended, so the page you were on is no longer available to you.
            Anything you had open is unchanged.
          </p>
        <% else %>
          <h2>This account is suspended</h2>
          <p>
            You can't sign in to huddlz right now. Public huddlz and groups are still open to browse.
          </p>
        <% end %>
        <p>
          If you think this is a mistake, write to <a href={"mailto:#{@support}"}>{@support}</a>
          from this email address and a person will look at it.
        </p>
        <.link navigate={~p"/discover"} class="btn-secondary">Browse huddlz</.link>
      </div>
    </Layouts.auth_shell>
    """
  end
end
