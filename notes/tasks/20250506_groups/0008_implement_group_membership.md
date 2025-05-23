# Task: Implement Group Membership

## Context
- Part of feature: Group Management
- Sequence: Task 8 of 8
- Purpose: Enable users to join and leave groups

## Task Boundaries
- In scope: 
  - Join public groups
  - Leave groups
  - View members list
  - Automatic membership for group creators
- Out of scope: 
  - Advanced membership management
  - Private group invitations (future enhancement)
  - Member roles beyond basic membership

## Current Status
- Progress: 100%
- Blockers: None
- Current activity: Completed

## Session Log
[2025-01-23] Starting implementation of this task...
[2025-01-23] Added join_group and leave_group actions to GroupMember resource
[2025-01-23] Created PublicGroup check to ensure only public groups can be joined
[2025-01-23] Updated group show LiveView with membership UI and functionality
[2025-01-23] Added comprehensive tests for membership functionality
[2025-01-23] Task completed successfully - users can now join/leave groups

## Requirements Analysis
- Implement join/leave functionality for public groups
- Automatically add group creator as a member
- Create a members list view
- Show join/leave buttons based on membership status
- Handle appropriate authorization for actions

## Implementation Plan
- Update Group resource with actions for managing membership
- Create UI for joining and leaving groups
- Implement automatic membership for group creators
- Build a members list component
- Add authorization checks for membership actions

## Implementation Checklist
1. Add join_group action to Group resource
2. Add leave_group action to Group resource
3. Ensure group creator becomes a member automatically
4. Create UI components for membership actions
5. Implement members list view
6. Add authorization checks for membership actions
7. Update group show page with membership functionality
8. Test all membership scenarios

## Related Files
- lib/huddlz/communities/group.ex (to update with membership actions)
- lib/huddlz_web/live/group_live/show.ex (to update with membership functionality)
- lib/huddlz_web/live/group_live/show.html.heex (to update with membership UI)
- lib/huddlz_web/live/group_live/members_component.ex (to create)

## Code Examples

### Updated Group Resource with Membership Actions
```elixir
# In lib/huddlz/communities/group.ex
actions do
  # Existing actions...
  
  update :join_group do
    description "Join a group"
    argument :user_id, :uuid do
      allow_nil? false
    end
    
    change manage_relationship(:user_id, :members, type: :append)
  end
  
  update :leave_group do
    description "Leave a group"
    argument :user_id, :uuid do
      allow_nil? false
    end
    
    change manage_relationship(:user_id, :members, type: :remove)
  end
  
  # Override the create action to automatically add creator as member
  create :create_group do
    description "Create a new group"
    accept [:name, :description, :location, :image_url, :is_public]
    
    argument :owner_id, :uuid do
      allow_nil? false
    end
    
    change manage_relationship(:owner_id, :owner, type: :append)
    
    # Also add owner as a member
    change after_action(fn changeset, result = %{} ->
      # Get the newly created group
      group = result.result
      
      # Add owner as member
      Huddlz.Communities.Group
      |> Ash.get!(group.id)
      |> Ash.Changeset.for_update(:join_group, %{user_id: changeset.arguments.owner_id})
      |> Ash.update!()
      
      # Return original result
      result
    end)
  end
end
```

### Group Show LiveView with Membership
```elixir
defmodule HuddlzWeb.GroupLive.Show do
  use HuddlzWeb, :live_view
  
  def mount(%{"id" => id}, _session, socket) do
    group = get_group(id)
    
    if group && (group.is_public || is_member?(group, socket.assigns.current_user)) do
      members = get_group_members(id)
      
      {:ok, 
        socket
        |> assign(:group, group)
        |> assign(:members, members)
        |> assign(:is_member, is_member?(group, socket.assigns.current_user))
        |> assign(:is_owner, is_owner?(group, socket.assigns.current_user))
      }
    else
      {:ok, 
        socket
        |> put_flash(:error, "You don't have access to this group")
        |> redirect(to: ~p"/groups")}
    end
  end
  
  def handle_event("join", _, socket) do
    case join_group(socket.assigns.group.id, socket.assigns.current_user.id) do
      {:ok, _} ->
        group = get_group(socket.assigns.group.id)
        members = get_group_members(socket.assigns.group.id)
        
        {:noreply, 
          socket
          |> put_flash(:info, "Successfully joined group")
          |> assign(:group, group)
          |> assign(:members, members)
          |> assign(:is_member, true)}
          
      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to join group")}
    end
  end
  
  def handle_event("leave", _, socket) do
    if socket.assigns.is_owner do
      {:noreply, put_flash(socket, :error, "Group owners cannot leave their group")}
    else
      case leave_group(socket.assigns.group.id, socket.assigns.current_user.id) do
        {:ok, _} ->
          group = get_group(socket.assigns.group.id)
          members = get_group_members(socket.assigns.group.id)
          
          {:noreply, 
            socket
            |> put_flash(:info, "Successfully left group")
            |> assign(:group, group)
            |> assign(:members, members)
            |> assign(:is_member, false)}
            
        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to leave group")}
      end
    end
  end
  
  # Helper functions
  defp get_group(id) do
    Huddlz.Communities.Group
    |> Ash.Query.filter(id == ^id)
    |> Ash.Query.load([:owner, :members])
    |> Ash.read_one!()
  end
  
  defp get_group_members(group_id) do
    Huddlz.Communities.Group
    |> Ash.get!(group_id)
    |> Ash.Query.load(:members)
    |> Ash.read_one!()
    |> Map.get(:members)
  end
  
  defp is_member?(group, user) do
    user && Enum.any?(group.members || [], fn member -> member.id == user.id end)
  end
  
  defp is_owner?(group, user) do
    user && group.owner && group.owner.id == user.id
  end
  
  defp join_group(group_id, user_id) do
    Huddlz.Communities.Group
    |> Ash.get!(group_id)
    |> Ash.Changeset.for_update(:join_group, %{user_id: user_id})
    |> Ash.update()
  end
  
  defp leave_group(group_id, user_id) do
    Huddlz.Communities.Group
    |> Ash.get!(group_id)
    |> Ash.Changeset.for_update(:leave_group, %{user_id: user_id})
    |> Ash.update()
  end
end
```

### Group Show Template with Membership
```heex
<.header>
  <%= @group.name %>
  <:subtitle><%= @group.description %></:subtitle>
  <:actions>
    <%= if @is_member do %>
      <.button phx-click="leave" data-confirm="Are you sure you want to leave this group?">
        Leave Group
      </.button>
    <% else %>
      <.button phx-click="join">
        Join Group
      </.button>
    <% end %>
  </:actions>
</.header>

<div class="mt-8">
  <h2 class="text-lg font-semibold">Group Details</h2>
  <dl class="mt-4 grid grid-cols-1 gap-x-6 gap-y-4 sm:grid-cols-2">
    <div>
      <dt class="text-sm font-medium text-gray-500">Location</dt>
      <dd class="mt-1 text-sm text-gray-900"><%= @group.location || "No location specified" %></dd>
    </div>
    <div>
      <dt class="text-sm font-medium text-gray-500">Owner</dt>
      <dd class="mt-1 text-sm text-gray-900"><%= @group.owner.display_name || @group.owner.email %></dd>
    </div>
    <div>
      <dt class="text-sm font-medium text-gray-500">Type</dt>
      <dd class="mt-1 text-sm text-gray-900"><%= if @group.is_public, do: "Public", else: "Private" %></dd>
    </div>
    <div>
      <dt class="text-sm font-medium text-gray-500">Members</dt>
      <dd class="mt-1 text-sm text-gray-900"><%= length(@members) %> members</dd>
    </div>
  </dl>
</div>

<div class="mt-8">
  <h2 class="text-lg font-semibold">Members</h2>
  <ul class="mt-4 grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3">
    <%= for member <- @members do %>
      <li class="flex items-center gap-2 rounded-md border p-3">
        <div class="flex-1">
          <p class="font-medium"><%= member.display_name || "User" %></p>
          <p class="text-sm text-gray-500"><%= member.email %></p>
        </div>
        <%= if @is_owner && member.id != @current_user.id do %>
          <button type="button" class="text-red-600 hover:text-red-900">
            Remove
          </button>
        <% end %>
      </li>
    <% end %>
  </ul>
</div>
```

## Definition of Done
- Users can join public groups
- Users can leave groups
- Group creators are automatically added as members
- Members list is visible on group pages
- Join/leave buttons appear based on membership status
- Group owners cannot leave their groups

## Quality Assurance

### AI Verification (Throughout Implementation)
- Verify join functionality works correctly
- Test leave functionality
- Confirm creator gets added as a member
- Test that owners cannot leave their groups
- Check authorization to ensure only public groups can be joined freely

### Human Verification (Required Before Next Task)
- After completing membership implementation, ask the user:
  "I've implemented the group membership functionality. Could you please verify the implementation by:
   1. Running the application (`mix phx.server`)
   2. Creating a group and confirming you're automatically a member
   3. Testing joining and leaving groups as different users
   4. Verifying the members list displays correctly
   If everything looks good, this completes the group management feature."

## Progress Tracking
- [x] Add join_group action to GroupMember resource - Completed
- [x] Add leave_group action to GroupMember resource - Completed  
- [x] Ensure group creator becomes a member automatically - Already implemented
- [x] Create UI components for membership actions - Completed
- [x] Implement members list view - Completed
- [x] Add authorization checks for membership actions - Completed
- [x] Update group show page with membership functionality - Completed
- [x] Test all membership scenarios - Completed

Note: Ownership transfer when owner leaves group deemed out of scope for this feature.

## Next Task
- This is the final task for the group management feature
- After completion, consider creating tests for the new functionality