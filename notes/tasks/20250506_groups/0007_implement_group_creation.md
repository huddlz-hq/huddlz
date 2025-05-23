# Task: Implement Group Creation

## Context
- Part of feature: Group Management
- Sequence: Task 7 of 8
- Purpose: Create UI and functionality for admin and verified users to create groups

## Task Boundaries
- In scope: 
  - Group creation form for admins and verified users
  - Group validation
  - Public/private group settings
  - Link from groups page to creation page
- Out of scope: 
  - Group membership management
  - Group content creation
  - Group deletion

## Current Status
- Progress: 100%
- Blockers: None
- Current activity: Completed

## Requirements Analysis
- Create a group creation form for admins and verified users
- Implement validation for group fields
- Add authorization to restrict creation to admins and verified users
- Include public/private toggle option
- Create navigation for group listing and creation

## Implementation Plan
- Create a new LiveView for group creation
- Implement form with all required fields
- Add validation for group name, description, etc.
- Create authorization checks for admin and verified users
- Build navigation for the groups section

## Implementation Checklist
1. Create groups LiveView for listing groups
2. Create group creation LiveView
3. Build group creation form with all fields
4. Add validation for required fields
5. Implement authorization to restrict to admins and verified users
6. Create navigation links for groups section
7. Add success/error messaging
8. Implement redirection after successful creation

## Related Files
- lib/huddlz_web/live/group_live.ex (to create)
- lib/huddlz_web/live/group_live/index.html.heex (to create)
- lib/huddlz_web/live/group_live/new.html.heex (to create)
- lib/huddlz_web/router.ex (to update with group routes)

## Code Examples

### Router Update
```elixir
# In lib/huddlz_web/router.ex
scope "/", HuddlzWeb do
  pipe_through [:browser, :require_authenticated_user]
  
  # Existing authenticated routes...
  
  live "/groups", GroupLive.Index, :index
  live "/groups/new", GroupLive.New, :new
  live "/groups/:id", GroupLive.Show, :show
end
```

### Group LiveView Index
```elixir
defmodule HuddlzWeb.GroupLive.Index do
  use HuddlzWeb, :live_view
  
  def mount(_params, _session, socket) do
    {:ok, 
      socket
      |> assign(:groups, list_groups())
      |> assign(:can_create_group, can_create_group?(socket.assigns.current_user))
    }
  end
  
  defp list_groups do
    # If public groups, anyone can see them
    Huddlz.Communities.Group
    |> Ash.Query.filter(is_public == true)
    |> Ash.read!()
  end
  
  defp can_create_group?(user) do
    user && user.role in ["admin", "verified"]
  end
end
```

### Group LiveView New
```elixir
defmodule HuddlzWeb.GroupLive.New do
  use HuddlzWeb, :live_view
  
  def mount(_params, _session, socket) do
    # Check if user can create groups
    if socket.assigns.current_user && 
       socket.assigns.current_user.role in ["admin", "verified"] do
      
      changeset = Huddlz.Communities.Group
        |> Ash.Changeset.for_create(:create, %{})
      
      {:ok, 
        socket
        |> assign(:changeset, changeset)
      }
    else
      {:ok, 
        socket
        |> put_flash(:error, "You need to be a verified user to create groups")
        |> redirect(to: ~p"/groups")}
    end
  end
  
  def handle_event("save", %{"group" => group_params}, socket) do
    # Add owner from current user
    params = Map.put(group_params, "owner_id", socket.assigns.current_user.id)
    
    case create_group(params) do
      {:ok, group} ->
        {:noreply,
          socket
          |> put_flash(:info, "Group created successfully")
          |> redirect(to: ~p"/groups/#{group.id}")}
          
      {:error, changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end
  
  defp create_group(params) do
    Huddlz.Communities.Group
    |> Ash.Changeset.for_create(:create_group, params)
    |> Ash.create()
  end
end
```

### Group Creation Template
```heex
<.header>
  Create a New Group
  <:subtitle>Create a group to organize huddlz and connect with others</:subtitle>
</.header>

<.simple_form :let={f} for={@changeset} phx-submit="save">
  <.input field={f[:name]} label="Group Name" required />
  <.input field={f[:description]} label="Description" type="textarea" />
  <.input field={f[:location]} label="Location" />
  <.input field={f[:image_url]} label="Image URL" />
  
  <div class="space-y-2">
    <.label>Privacy</.label>
    <div class="flex items-center gap-4">
      <.input field={f[:is_public]} label="Public group (anyone can join)" type="checkbox" checked={true} />
    </div>
    <.hint>Public groups are visible to everyone and anyone can join. Private groups require invitations.</.hint>
  </div>
  
  <:actions>
    <.button type="submit" phx-disable-with="Creating...">Create Group</.button>
  </:actions>
</.simple_form>
```

## Definition of Done
- Group creation form is implemented
- Only admins and verified users can create groups
- Group validation works correctly
- Public/private setting works
- Navigation between groups index and creation page works
- Successful creation redirects to the group page

## Quality Assurance

### AI Verification (Throughout Implementation)
- Verify form validation works correctly
- Check authorization to ensure only admins and verified users can create groups
- Test public/private setting is saved correctly
- Ensure owner relationship is established

### Human Verification (Required Before Next Task)
- After completing group creation, ask the user:
  "I've implemented the group creation functionality. Could you please verify the implementation by:
   1. Running the application (`mix phx.server`)
   2. Logging in as an admin or verified user
   3. Creating a new group and verifying it appears in the listing
   If everything looks good, I'll proceed to the next task."

## Progress Tracking
1. Create groups LiveView for listing groups - ✅ [May 22, 2025]
2. Create group creation LiveView - ✅ [May 22, 2025]
3. Build group creation form with all fields - ✅ [May 22, 2025]
4. Add validation for required fields - ✅ [May 22, 2025]
5. Implement authorization to restrict to admins and verified users - ✅ [May 22, 2025]
6. Create navigation links for groups section - ✅ [May 22, 2025]
7. Add success/error messaging - ✅ [May 22, 2025]
8. Implement redirection after successful creation - ✅ [May 22, 2025]

## Session Log
- [May 22, 2025] Starting implementation of this task...
- [May 22, 2025] Created GroupLive.Index for listing groups
- [May 22, 2025] Created GroupLive.New for creating groups
- [May 22, 2025] Created GroupLive.Show for viewing individual groups
- [May 22, 2025] Added router entries for all group routes
- [May 22, 2025] Added Groups link to navigation bar
- [May 22, 2025] Fixed compilation issues (removed simple_form, fixed Ash.Query.filter)
- [May 22, 2025] All tests passing (70 tests, 0 failures)
- [May 22, 2025] Task completed successfully

## Next Task
- Next task: 0008_implement_group_membership
- Only proceed to the next task after this task is complete and verified