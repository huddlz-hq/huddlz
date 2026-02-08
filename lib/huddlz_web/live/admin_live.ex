defmodule HuddlzWeb.AdminLive do
  @moduledoc """
  LiveView for admin user management and role assignment.
  """
  use HuddlzWeb, :live_view

  alias Huddlz.Accounts
  alias HuddlzWeb.Layouts

  # Ensure only admins can access this page
  on_mount {HuddlzWeb.LiveUserAuth, role_required: :admin}

  @impl true
  def mount(_params, _session, socket) do
    # The on_mount hook already checked admin permissions
    # On initial load, list all users
    {:ok, all_users} = list_all_users(socket.assigns.current_user)
    {:ok, assign(socket, users: all_users, search_query: "", search_performed: true)}
  end

  # Helper to list all users
  defp list_all_users(current_user) do
    # We're already checking for admin access with the on_mount hook
    Accounts.search_by_email("", actor: current_user)
  end

  @impl true
  def handle_event("search", %{"query" => query}, socket) do
    # Remove empty spaces
    query = String.trim(query)

    # Search by email (even with empty query, which returns all users)
    # We're already checking for admin access with the on_mount hook
    {:ok, users} = Accounts.search_by_email(query, actor: socket.assigns.current_user)
    {:noreply, assign(socket, users: users, search_query: query, search_performed: true)}
  end

  @impl true
  def handle_event("clear_search", _params, socket) do
    {:ok, all_users} = list_all_users(socket.assigns.current_user)
    {:noreply, assign(socket, users: all_users, search_query: "", search_performed: true)}
  end

  @impl true
  def handle_event("update_role", %{"user_id" => user_id, "role" => role}, socket) do
    role_atom = String.to_existing_atom(role)

    # Use with statement to handle errors more elegantly
    # Note: From now on, we prefer with statements over case unless required otherwise
    with {:ok, user} <-
           Ash.get(Huddlz.Accounts.User, user_id, actor: socket.assigns.current_user),
         {:ok, updated_user} <-
           Accounts.update_role(user, role_atom, actor: socket.assigns.current_user) do
      updated_users = replace_user(socket.assigns.users, updated_user)

      {:noreply,
       socket
       |> assign(users: updated_users)
       |> put_flash(:info, "User role updated successfully")}
    else
      {:error, %Ash.Error.Query.NotFound{}} ->
        {:noreply, put_flash(socket, :error, "User not found")}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Failed to update user role")}
    end
  end

  defp replace_user(users, updated_user) do
    Enum.map(users, fn user ->
      if user.id == updated_user.id, do: updated_user, else: user
    end)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <div class="container mx-auto p-4 sm:p-6 lg:p-8">
        <div class="mb-8">
          <h1 class="font-display text-2xl tracking-tight">Admin Panel</h1>
        </div>

        <div class="border border-base-300">
          <div class="p-6">
            <h2 class="font-display text-lg tracking-tight text-glow mb-4">User Management</h2>

            <form phx-submit="search" class="mb-6">
              <div class="flex gap-2 w-full">
                <input
                  type="text"
                  name="query"
                  value={@search_query}
                  placeholder="Search users by email..."
                  class="flex-1 border border-base-300 px-4 py-2.5 bg-base-100 text-sm focus:border-primary focus:ring-1 focus:ring-primary/30 transition-colors"
                />
                <button
                  type="submit"
                  class="px-5 py-2.5 bg-primary text-primary-content text-sm font-medium btn-neon"
                >
                  Search
                </button>
                <button
                  type="button"
                  phx-click="clear_search"
                  class="px-5 py-2.5 border border-base-300 text-sm font-medium hover:border-primary/30 transition-colors"
                >
                  Clear
                </button>
              </div>
            </form>

            <%= if @search_performed do %>
              <%= if Enum.empty?(@users) do %>
                <div class="border border-primary/20 p-4 bg-primary/5 flex items-start gap-3">
                  <.icon
                    name="hero-information-circle"
                    class="w-5 h-5 text-primary flex-shrink-0 mt-0.5"
                  />
                  <span>No users found matching your search criteria.</span>
                </div>
              <% else %>
                <div class="overflow-x-auto">
                  <table class="w-full">
                    <thead>
                      <tr class="text-left mono-label text-primary/70 border-b border-base-300">
                        <th class="px-4 py-3">Email</th>
                        <th class="px-4 py-3">Display Name</th>
                        <th class="px-4 py-3">Role</th>
                        <th class="px-4 py-3">Actions</th>
                      </tr>
                    </thead>
                    <tbody>
                      <%= for user <- @users do %>
                        <tr class="border-b border-base-300 hover:bg-base-300/50 transition-colors">
                          <td class="px-4 py-3 text-sm">{user.email}</td>
                          <td class="px-4 py-3 text-sm">{user.display_name || "—"}</td>
                          <td class="px-4 py-3 text-sm">
                            <span class={"text-xs px-2.5 py-1 font-medium #{if user.role == :admin, do: "bg-primary/10 text-primary", else: "bg-base-300 text-base-content/50"}"}>
                              {user.role}
                            </span>
                          </td>
                          <td class="px-4 py-3 text-sm">
                            <form phx-submit="update_role" class="flex items-center gap-2">
                              <input type="hidden" name="user_id" value={user.id} />
                              <select
                                name="role"
                                class="border border-base-300 px-2 py-1 text-sm bg-base-100 focus:border-primary transition-colors"
                              >
                                <option value="user" selected={user.role == :user}>User</option>
                                <option value="admin" selected={user.role == :admin}>Admin</option>
                              </select>
                              <button
                                type="submit"
                                class="px-3 py-1 bg-primary text-primary-content text-xs font-medium btn-neon transition-all"
                              >
                                Update
                              </button>
                            </form>
                          </td>
                        </tr>
                      <% end %>
                    </tbody>
                  </table>
                </div>
              <% end %>
            <% end %>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
