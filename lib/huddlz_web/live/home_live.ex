defmodule HuddlzWeb.HomeLive do
  use HuddlzWeb, :live_view

  alias HuddlzWeb.Layouts

  # Ensure current_user is available for the navbar
  on_mount {HuddlzWeb.LiveUserAuth, :live_user_optional}

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <!-- Empty home page for now -->
    </Layouts.app>
    """
  end
end
