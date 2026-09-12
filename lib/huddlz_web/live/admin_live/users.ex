defmodule HuddlzWeb.AdminLive.Users do
  @moduledoc """
  Admin user management and role assignment, at `/admin/users`.
  """
  use HuddlzWeb, :live_view

  alias Huddlz.Accounts
  alias HuddlzWeb.Layouts

  on_mount {HuddlzWeb.LiveUserAuth, :admin_required}
  on_mount {HuddlzWeb.LiveUserAuth, :app}

  @impl true
  def mount(_params, _session, socket) do
    {:ok, all_users} = list_all_users(socket.assigns.current_user)

    {:ok,
     socket
     |> assign(:page_title, "Users")
     |> assign(:users, all_users)
     |> assign(:search_query, "")
     |> assign(:search_performed, true)}
  end

  defp list_all_users(current_user) do
    Accounts.search_by_email("", actor: current_user)
  end

  @impl true
  def handle_event("search", %{"query" => query}, socket) do
    query = String.trim(query)
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
    <Layouts.app
      flash={@flash}
      current_user={@current_user}
      unread_notification_count={@unread_notification_count}
      sidebar_owned_groups={@sidebar_owned_groups}
      active="admin"
      active_admin_section={:users}
    >
      <div class="page-head">
        <div>
          <h1>Users</h1>
          <p>Manage user accounts and roles across huddlz.</p>
        </div>
      </div>

      <div class="panel">
        <div class="panel-head">
          <h2>User Management</h2>
          <span class="panel-sub">{user_count_label(length(@users))}</span>
        </div>

        <form phx-submit="search" class="admin-search">
          <input
            type="text"
            name="query"
            value={@search_query}
            placeholder="Search users by email..."
            class="form-input"
          />
          <button type="submit" class="btn-primary">Search</button>
          <button type="button" class="btn-secondary" phx-click="clear_search">Clear</button>
        </form>

        <%= if @search_performed do %>
          <%= if Enum.empty?(@users) do %>
            <p class="muted">No users found matching your search criteria.</p>
          <% else %>
            <table class="admin-table">
              <thead>
                <tr>
                  <th>Email</th>
                  <th>Display Name</th>
                  <th>Role</th>
                  <th>Actions</th>
                </tr>
              </thead>
              <tbody>
                <tr :for={user <- @users}>
                  <td data-label="Email">{user.email}</td>
                  <td data-label="Display Name">{user.display_name || "—"}</td>
                  <td data-label="Role">
                    <span class={["pill", role_pill_variant(user.role)]}>{user.role}</span>
                  </td>
                  <td data-label="Actions">
                    <.link
                      :if={viewable_as?(user, @current_user)}
                      href={~p"/admin/impersonations/#{user.id}"}
                      method="post"
                      class="btn-secondary view-as"
                      aria-label={"View as #{user.email}"}
                    >
                      View as
                    </.link>
                    <%= if Ash.can?({user, :update_role}, @current_user) do %>
                      <form id={"role-form-#{user.id}"} phx-submit="update_role" class="role-form">
                        <input type="hidden" name="user_id" value={user.id} />
                        <select
                          name="role"
                          class="form-select"
                          aria-label={"Role for #{user.email}"}
                        >
                          <option value="user" selected={user.role == :user}>User</option>
                          <option value="admin" selected={user.role == :admin}>Admin</option>
                        </select>
                        <button
                          type="submit"
                          class="btn-primary"
                          aria-label={"Update role for #{user.email}"}
                        >
                          Update
                        </button>
                      </form>
                    <% else %>
                      <span class="muted">You</span>
                    <% end %>
                  </td>
                </tr>
              </tbody>
            </table>
          <% end %>
        <% end %>
      </div>
    </Layouts.app>
    """
  end

  # Administrators view huddlz as other people, never as each other.
  defp viewable_as?(%{role: :admin}, _admin), do: false
  defp viewable_as?(%{id: id}, %{id: id}), do: false
  defp viewable_as?(_user, _admin), do: true

  defp user_count_label(1), do: "1 user"
  defp user_count_label(n), do: "#{n} users"

  # Mirrors `ProfileLive`'s mapping so the same user's role pill renders the
  # same color across both pages.
  defp role_pill_variant(:admin), do: "magenta"
  defp role_pill_variant(_), do: "cyan"
end
