defmodule HuddlzWeb.AdminLive do
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
      # Update the user in the list
      updated_users =
        Enum.map(socket.assigns.users, fn user ->
          if user.id == updated_user.id, do: updated_user, else: user
        end)

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

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <div class="container mx-auto px-4 py-8">
        <h1 class="text-3xl font-bold mb-6">Admin Panel</h1>

        <div class="mb-8">
          <h2 class="text-xl font-semibold mb-4">User Management</h2>

          <form phx-submit="search" class="mb-6">
            <div class="flex">
              <input
                type="text"
                name="query"
                value={@search_query}
                placeholder="Search users by email..."
                class="flex-grow px-4 py-2 border rounded-l focus:outline-none bg-base-100 text-base-content"
              />
              <button type="submit" class="btn btn-primary px-4 py-2 rounded-r">
                Search
              </button>
              <button
                type="button"
                phx-click="clear_search"
                class="btn btn-secondary px-4 py-2 rounded ml-2"
              >
                Clear
              </button>
            </div>
          </form>

          <%= if @search_performed do %>
            <%= if Enum.empty?(@users) do %>
              <div class="text-center py-8 bg-base-200 rounded">
                <p class="text-lg text-base-content/70">
                  No users found matching your search criteria.
                </p>
              </div>
            <% else %>
              <div class="overflow-x-auto">
                <table class="table w-full">
                  <thead>
                    <tr>
                      <th>Email</th>
                      <th>Display Name</th>
                      <th>Role</th>
                      <th>Actions</th>
                    </tr>
                  </thead>
                  <tbody>
                    <%= for user <- @users do %>
                      <tr>
                        <td>{user.email}</td>
                        <td>{user.display_name || "—"}</td>
                        <td>
                          <span class={"badge #{role_badge_class(user.role)}"}>{user.role}</span>
                        </td>
                        <td>
                          <form phx-submit="update_role" class="flex items-center">
                            <input type="hidden" name="user_id" value={user.id} />
                            <select name="role" class="select select-sm mr-2">
                              <option value="user" selected={user.role == :user}>User</option>
                              <option value="admin" selected={user.role == :admin}>Admin</option>
                            </select>
                            <button type="submit" class="btn btn-primary btn-sm">Update</button>
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
    </Layouts.app>
    """
  end

  # Helper function to determine badge color based on role
  defp role_badge_class(:admin), do: "badge-primary"
  defp role_badge_class(:user), do: "badge-ghost"
end
