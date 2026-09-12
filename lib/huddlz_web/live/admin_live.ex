defmodule HuddlzWeb.AdminLive do
  @moduledoc """
  The admin overview at `/admin`: how huddlz as a whole is doing.
  """
  use HuddlzWeb, :live_view

  alias HuddlzWeb.Layouts

  on_mount {HuddlzWeb.LiveUserAuth, :admin_required}
  on_mount {HuddlzWeb.LiveUserAuth, :app}

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :page_title, "Admin")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_user={@current_user}
      unread_notification_count={@unread_notification_count}
      sidebar_owned_groups={@sidebar_owned_groups}
      active="admin"
      active_admin_section={:overview}
    >
      <div class="page-head">
        <div>
          <h1>Overview</h1>
          <p>How huddlz as a whole is doing: who is joining, what is being held, and who shows up.</p>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
