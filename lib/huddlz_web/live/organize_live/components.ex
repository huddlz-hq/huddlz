defmodule HuddlzWeb.OrganizeLive.Components do
  @moduledoc """
  Shared chrome for the organizer workspace at `/organize`. Used by
  `HuddlzWeb.OrganizeLive` (the dashboard tabs) and any subview that wants to
  render inside the workspace sidebar shell (e.g. the workspace create-huddl
  form on `/organize/huddlz/new`).
  """
  use Phoenix.Component
  use HuddlzWeb, :verified_routes

  attr :active, :atom, required: true
  attr :current_user, :map, required: true
  slot :inner_block, required: true

  def workspace_chrome(assigns) do
    ~H"""
    <div class="grid grid-cols-1 lg:grid-cols-[260px_minmax(0,1fr)] gap-6 lg:gap-10">
      <.workspace_sidebar active={@active} current_user={@current_user} />
      <div class="space-y-10 min-w-0">
        {render_slot(@inner_block)}
      </div>
    </div>
    """
  end

  attr :active, :atom, required: true
  attr :current_user, :map, required: true

  defp workspace_sidebar(assigns) do
    ~H"""
    <aside class="border border-base-300 self-start lg:sticky lg:top-28">
      <div class="border-b border-base-300 px-5 py-4">
        <span class="mono-label text-primary/70">// Workspace</span>
        <p class="text-base font-extrabold tracking-tight text-base-content mt-1">Organizer</p>
        <p class="text-xs text-base-content/50 mt-1">
          Operations across your groups and huddlz.
        </p>
      </div>

      <nav class="p-3 flex flex-col gap-1.5" aria-label="Organizer workspace tabs">
        <.sidebar_link active={@active} action={:overview} label="Overview" path={~p"/organize"} />
        <.sidebar_link
          active={@active}
          action={:groups}
          label="Groups"
          path={~p"/organize/groups"}
        />
        <.sidebar_link
          active={@active}
          action={:huddlz}
          label="Huddlz"
          path={~p"/organize/huddlz"}
        />
        <.sidebar_link
          active={@active}
          action={:calendar}
          label="Calendar"
          path={~p"/organize/calendar"}
        />
        <.sidebar_link
          active={@active}
          action={:attendees}
          label="Attendees"
          path={~p"/organize/attendees"}
        />
        <.sidebar_link
          active={@active}
          action={:members}
          label="Members"
          path={~p"/organize/members"}
        />
        <.sidebar_link
          active={@active}
          action={:settings}
          label="Settings"
          path={~p"/organize/settings"}
        />
      </nav>

      <div class="border-t border-base-300 px-5 py-3 text-xs text-base-content/50">
        Signed in as
        <span class="text-base-content/80 font-bold block truncate">
          {@current_user.display_name || @current_user.email}
        </span>
      </div>
    </aside>
    """
  end

  attr :active, :atom, required: true
  attr :action, :atom, required: true
  attr :label, :string, required: true
  attr :path, :string, required: true

  defp sidebar_link(assigns) do
    ~H"""
    <.link navigate={@path} class={sidebar_link_class(@active == @action)}>
      {@label}
    </.link>
    """
  end

  defp sidebar_link_class(true) do
    "block px-3 py-2 text-sm font-bold border border-primary bg-primary/10 text-primary"
  end

  defp sidebar_link_class(false) do
    "block px-3 py-2 text-sm font-bold border border-transparent text-base-content/80 hover:border-base-300 hover:text-primary transition-colors"
  end
end
