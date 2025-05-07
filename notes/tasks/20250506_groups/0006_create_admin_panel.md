# Task: Create Admin Panel

## Context
- Part of feature: Group Management
- Sequence: Task 6 of 8
- Purpose: Create an admin panel for managing user permissions and viewing groups

## Task Boundaries
- In scope: 
  - Admin-only interface for managing users and permissions
  - User search functionality
  - User permission management (admin, verified, regular)
  - User role updating capability
- Out of scope: 
  - Advanced user management features
  - Group content moderation
  - Usage analytics

## Current Status
- Progress: 0%
- Blockers: None
- Next steps: Begin implementation

## Requirements Analysis
- Create an admin-only panel accessible via authentication
- Build user search functionality to find users by email
- Display user information including current role
- Implement role management (change between admin, verified, regular)
- Add navigation links for admin users only
- Ensure proper authorization to prevent non-admins from accessing

## Implementation Plan
- Create a new LiveView for the admin panel
- Implement a role field in the User resource
- Add admin role check in router or LiveView
- Create user search functionality with Ash queries
- Build UI for displaying and updating user roles
- Add navigation links that are only visible to admins

## Implementation Checklist
1. Update User resource to include a role field (admin, verified, regular)
2. Create LiveView module for admin panel
3. Add admin panel routes with proper authorization
4. Implement user search functionality
5. Build user listing with role display
6. Add role updating functionality
7. Create admin-only navigation links
8. Implement verification of role changes

## Related Files
- lib/huddlz/accounts/user.ex (to update with role field)
- lib/huddlz_web/live/admin_live.ex (to create)
- lib/huddlz_web/router.ex (to update with admin routes)
- lib/huddlz_web/components/layouts.ex (to update navigation)

## Code Examples

### Updated User Resource with Roles
```elixir
# In lib/huddlz/accounts/user.ex
attributes do
  uuid_primary_key :id

  attribute :email, :ci_string do
    allow_nil? false
    public? true
  end

  attribute :display_name, :string do
    allow_nil? true
    public? true
    description "User's display name shown in the UI"
  end
  
  attribute :role, :string do
    allow_nil? false
    default "regular"
    constraints one_of: ["regular", "verified", "admin"]
    description "User's role for permissions"
  end
end

# Add role update action
actions do
  # Existing actions...
  
  update :update_role do
    description "Update a user's role"
    argument :role, :string do
      allow_nil? false
      constraints one_of: ["regular", "verified", "admin"]
    end
    
    change fn changeset, _context ->
      Ash.Changeset.change_attribute(changeset, :role, changeset.arguments.role)
    end
  end
end
```

### Admin LiveView
```elixir
defmodule HuddlzWeb.AdminLive do
  use HuddlzWeb, :live_view
  
  def mount(_params, _session, socket) do
    # Verify admin access
    if socket.assigns.current_user && socket.assigns.current_user.role == "admin" do
      {:ok, assign(socket, 
        page_title: "Admin Panel",
        search_results: [],
        search_term: "",
        error_message: nil
      )}
    else
      {:ok, 
        socket
        |> put_flash(:error, "You don't have permission to access this page")
        |> redirect(to: ~p"/")}
    end
  end
  
  def handle_event("search", %{"search" => %{"term" => term}}, socket) do
    # Implement user search
    case search_users(term) do
      {:ok, users} ->
        {:noreply, assign(socket, search_results: users, search_term: term, error_message: nil)}
      {:error, message} ->
        {:noreply, assign(socket, error_message: message)}
    end
  end
  
  def handle_event("update_role", %{"id" => id, "role" => role}, socket) do
    # Implement role update
    case update_user_role(id, role) do
      {:ok, _} ->
        # Re-search to refresh the list
        {:ok, users} = search_users(socket.assigns.search_term)
        {:noreply, 
          socket
          |> put_flash(:info, "User role updated successfully")
          |> assign(search_results: users)}
      
      {:error, message} ->
        {:noreply, 
          socket
          |> put_flash(:error, "Failed to update role: #{message}")}
    end
  end
  
  # Helper functions for searching users and updating roles
  defp search_users(term) do
    Huddlz.Accounts.User
    |> Ash.Query.filter(like(email, ^"%#{term}%"))
    |> Ash.read()
  end
  
  defp update_user_role(id, role) do
    Huddlz.Accounts.User
    |> Ash.get!(id)
    |> Ash.Changeset.for_update(:update_role, %{role: role})
    |> Ash.update()
  end
end
```

### Router Update
```elixir
# In lib/huddlz_web/router.ex
scope "/", HuddlzWeb do
  pipe_through [:browser, :require_authenticated_user]
  
  # Existing authenticated routes...
  
  # Admin routes - will be further restricted in the LiveView
  live "/admin", AdminLive, :index
end
```

## Definition of Done
- User resource has role field with proper constraints
- Admin panel LiveView is created with proper authorization
- Users can be searched by email
- Admin users can change roles of other users
- Non-admin users cannot access the admin panel
- All tests pass

## Quality Assurance

### AI Verification (Throughout Implementation)
- Verify proper authorization checks in LiveView and router
- Test user search functionality
- Ensure role updates work correctly
- Check navigation links for admin-only visibility

### Human Verification (Required Before Next Task)
- After completing the admin panel, ask the user:
  "I've implemented the admin panel for user role management. Could you please verify the implementation by:
   1. Running the application (`mix phx.server`)
   2. Logging in as an admin user
   3. Accessing the admin panel and testing role updates
   If everything looks good, I'll proceed to the next task."

## Progress Tracking
- Update after completing each checklist item
- Mark items as completed with timestamps
- Document any issues encountered and how they were resolved

## Next Task
- Next task: 0007_implement_group_creation
- Only proceed to the next task after this task is complete and verified