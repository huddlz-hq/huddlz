# Ash Framework: Access Control

This document covers how to implement a flexible permissions system in Ash Framework applications, enabling role-based access control (RBAC) through user groups and dynamically discovering available permissions.

## Table of Contents

- [Understanding the Permission Model](#understanding-the-permission-model)
- [Streamlining the Permission Model](#streamlining-the-permission-model)
- [Implementing the GroupPermission Resource](#implementing-the-grouppermission-resource)
- [Updating Group Relationships](#updating-group-relationships)
- [Dynamically Discovering Permissions](#dynamically-discovering-permissions)
- [Implementing the Authorization Check](#implementing-the-authorization-check)
- [UI Implementation for Access Control](#ui-implementation-for-access-control)

## Understanding the Permission Model

A typical permissions model in Ash involves:

1. **Groups**: Collections of users who share the same access rights
2. **Permissions**: Specific actions allowed on specific resources
3. **GroupPermissions**: Join table linking groups to their permissions
4. **UserGroups**: Join table linking users to their groups

Instead of maintaining a separate Permissions resource, we can leverage Ash's introspection capabilities to dynamically discover all available permissions from the application's resources and actions.

## Streamlining the Permission Model

The simplified GroupPermission schema:

| Attribute   | Type         | Description                      |
|------------|-------------|----------------------------------|
| action     | String      | Name of the action on a resource |
| resource   | String      | Name of the resource             |
| group_id   | String, UUID | Access Group Identifier         |
| inserted_at | Timestamp   | Time it was created             |
| updated_at | Timestamp   | Time it was edited               |

This approach:
- Simplifies the data model
- Reduces database queries
- Makes permission checks more straightforward
- Leverages Ash's introspection capabilities

## Implementing the GroupPermission Resource

```elixir
defmodule Helpcenter.Accounts.GroupPermission do
  use Ash.Resource,
    domain: Helpcenter.Accounts,
    data_layer: AshPostgres.DataLayer,
    notifiers: Ash.Notifier.PubSub

  postgres do
    table "group_permissions"
    repo Helpcenter.Repo
  end

  actions do
    default_accept [:resource, :action, :group_id]
    defaults [:create, :read, :update, :destroy]
  end

  preparations do
    prepare Helpcenter.Preparations.SetTenant
  end

  changes do
    change Helpcenter.Changes.SetTenant
  end

  multitenancy do
    strategy :context
  end

  attributes do
    uuid_v7_primary_key :id
    attribute :action, :string, allow_nil?: false
    attribute :resource, :string, allow_nil?: false
    timestamps()
  end

  relationships do
    belongs_to :group, Helpcenter.Accounts.Group do
      description "Relationship with a group inside a tenant"
      source_attribute :group_id
      allow_nil? false
    end
  end

  identities do
    identity :unique_name, [:group_id, :resource, :action]
  end
end
```

## Updating Group Relationships

Update the Group resource to reference GroupPermission directly:

```elixir
# In the Group resource
relationships do
  has_many :permissions, Helpcenter.Accounts.GroupPermission do
    description "List of permissions assigned to this group"
    destination_attribute :group_id
  end
  
  # Other relationships...
end
```

## Dynamically Discovering Permissions

Create a module to introspect the application and discover all available permissions:

```elixir
defmodule Helpcenter.Accounts.Permission do
  @doc """
  Get a list of maps of resources and their actions
  Example:
    iex> Helpcenter.Accounts.Permission.permissions()
    iex> [%{resource: Helpcenter.Accounts.GroupPermission, action: :create}]
  """
  def permissions() do
    get_all_domain_resources()
    |> Enum.map(&map_resource_actions/1)
    |> Enum.flat_map(& &1)
  end

  defp map_resource_action(action, resource) do
    %{action: action.name, resource: resource}
  end

  defp map_resource_actions(resource) do
    Ash.Resource.Info.actions(resource)
    |> Enum.map(&map_resource_action(&1, resource))
  end

  defp get_all_domain_resources() do
    Application.get_env(:helpcenter, :ash_domains)
    |> Enum.map(&Ash.Domain.Info.resources(&1))
    |> Enum.flat_map(& &1)
  end
end
```

Add a convenience function to access permissions from the main application module:

```elixir
defmodule Helpcenter do
  defdelegate permissions(), to: Helpcenter.Accounts.Permission
end
```

## Implementing the Authorization Check

The authorization check module determines if a user can perform a specific action:

```elixir
defmodule Helpcenter.Accounts.Checks.Authorized do
  use Ash.Policy.SimpleCheck
  require Ash.Query

  @impl true
  def describe(_opts), do: "Authorize User Access Group"

  @impl true
  def match?(nil = _actor, _context, _opts), do: false
  def match?(actor, context, _options), do: authorized?(actor, context)

  defp authorized?(actor, context) do
    cond do
      is_current_team_owner?(actor) -> true
      true -> can?(actor, context)
    end
  end

  # Confirms if the actor is the owner of the current team
  defp is_current_team_owner?(actor) do
    Helpcenter.Accounts.Team
    |> Ash.Query.filter(owner_user_id == ^actor.id)
    |> Ash.Query.filter(domain == ^actor.current_team)
    |> Ash.exists?()
  end

  # Checks if the actor has the required permission
  defp can?(actor, context) do
    Helpcenter.Accounts.User
    |> Ash.Query.filter(id == ^actor.id)
    |> Ash.Query.load(groups: :permissions)
    |> Ash.Query.filter(groups.permissions.resource == ^context.resource)
    |> Ash.Query.filter(groups.permissions.action == ^context.subject.action.type)
    |> Ash.exists?(tenant: actor.current_team, authorize?: false)
  end
end
```

This check:
1. Always grants access to team owners
2. For others, checks if they have the required permission in any of their groups

## UI Implementation for Access Control

### 1. Test-Driven Approach

Start with tests that verify:
- Group form rendering
- Group listing functionality
- Group permission editing

```elixir
defmodule Helpcenter.Accounts.AccessGroupLiveTest do
  use HelpcenterWeb.ConnCase, async: false
  
  test "All resource actions can be listed for permissions" do
    assert Helpcenter.permissions() |> is_list()
  end
  
  test "Group form renders successfully" do
    user = create_user()
    
    assigns = %{
      actor: user,
      group_id: nil,
      id: Ash.UUIDv7.generate()
    }
    
    html = render_component(HelpcenterWeb.Accounts.Groups.GroupForm, assigns)
    
    # Verify form components
    assert html =~ "access-group-modal-button"
    assert html =~ "form[name]"
    assert html =~ "form[description]"
    assert html =~ gettext("Submit")
  end
  
  # Additional tests...
end
```

### 2. Group Form Component

Create a LiveComponent for creating/editing groups:

```elixir
defmodule HelpcenterWeb.Accounts.Groups.GroupForm do
  use HelpcenterWeb, :live_component
  alias AshPhoenix.Form

  # Function component interface
  attr :id, :string, required: true
  attr :group_id, :string, default: nil
  attr :show_button, :boolean, default: true
  attr :actor, Helpcenter.Accounts.User, required: true

  def form(assigns) do
    ~H"""
    <.live_component
      id={@id}
      actor={@actor}
      module={__MODULE__}
      group_id={@group_id}
      show_button={@show_button}
    />
    """
  end

  # Component implementation
  def render(assigns) do
    ~H"""
    <div id={"access-group-#{@group_id}"} class="mt-4">
      <!-- Form button -->
      <div class="flex justify-end">
        <.button
          :if={@show_button}
          phx-click={show_modal("access-group-form-modal#{@group_id}")}
          id={"access-group-modal-button#{@group_id}"}
        >
          <.icon name="hero-plus-solid" class="h-5 w-5" />
        </.button>
      </div>

      <!-- Form modal -->
      <.modal id={"access-group-form-modal#{@group_id}"}>
        <.header class="mt-4">
          <.icon name="hero-user-group" />
          <!-- Title based on new/edit mode -->
          <span :if={is_nil(@group_id)}>{gettext("New Access Group")}</span>
          <span :if={@group_id}>{@form.source.data.name}</span>
          
          <!-- Subtitle based on new/edit mode -->
          <:subtitle :if={is_nil(@group_id)}>
            {gettext("Fill below form to create a new user access group")}
          </:subtitle>
          <:subtitle :if={@group_id}>
            {gettext("Fill below form to update %{name} access group details.",
              name: @form.source.data.name
            )}
          </:subtitle>
        </.header>
        
        <!-- Form -->
        <.simple_form
          for={@form}
          phx-change="validate"
          phx-submit="save"
          id={"access-group-form#{@group_id}"}
          phx-target={@myself}
        >
          <.input
            field={@form[:name]}
            id={"access-group-name#{@id}-#{@group_id}"}
            label={gettext("Access Group Name")}
          />
          <.input
            field={@form[:description]}
            id={"access-group-description#{@id}-#{@group_id}"}
            type="textarea"
            label={gettext("Description")}
          />
          <:actions>
            <.button class="w-full" phx-disable-with={gettext("Saving...")}>
              {gettext("Submit")}
            </.button>
          </:actions>
        </.simple_form>
      </.modal>
    </div>
    """
  end

  # Component lifecycle functions
  def update(assigns, socket) do
    socket
    |> assign(assigns)
    |> assign_form()
    |> ok()
  end

  # Event handlers
  def handle_event("validate", %{"form" => attrs}, socket) do
    socket
    |> assign(:form, Form.validate(socket.assigns.form, attrs))
    |> noreply()
  end

  def handle_event("save", %{"form" => attrs}, socket) do
    case Form.submit(socket.assigns.form, params: attrs) do
      {:ok, _group} ->
        socket
        |> put_component_flash(:info, gettext("Access Group Submitted."))
        |> cancel_modal("access-group-form-modal#{socket.assigns.group_id}")
        |> noreply()

      {:error, form} ->
        socket
        |> assign(:form, form)
        |> noreply()
    end
  end

  # Form helpers
  defp assign_form(%{assigns: %{form: _form}} = socket), do: socket

  defp assign_form(%{assigns: assigns} = socket) do
    assign(socket, :form, get_form(assigns))
  end

  defp get_form(%{group_id: nil} = assigns) do
    Helpcenter.Accounts.Group
    |> Form.for_create(:create, actor: assigns.actor)
    |> to_form()
  end

  defp get_form(%{group_id: group_id} = assigns) do
    Helpcenter.Accounts.Group
    |> Ash.get!(group_id, actor: assigns.actor)
    |> Form.for_update(:update, actor: assigns.actor)
    |> to_form()
  end
end
```

### 3. Group List LiveView

Create a LiveView for listing and managing groups:

```elixir
defmodule HelpcenterWeb.Accounts.Groups.GroupsLive do
  use HelpcenterWeb, :live_view

  def render(assigns) do
    ~H"""
    <div class="flex justify-between">
      <.header class="mt-4">
        <.icon name="hero-user-group-solid" /> {gettext("User Access Groups")}
        <:subtitle>
          {gettext("Create, update and manage user access groups and their permissions")}
        </:subtitle>
      </.header>
      <!-- Group create form -->
      <HelpcenterWeb.Accounts.Groups.GroupForm.form actor={@current_user} id={Ash.UUIDv7.generate()} />
    </div>
    
    <!-- Group table -->
    <.table id="groups" rows={@groups}>
      <:col :let={group} label={gettext("Name")}>{group.name}</:col>
      <:col :let={group} label={gettext("Description")}>{group.description}</:col>
      <:action :let={group}>
        <div class="space-x-6">
          <!-- Edit button -->
          <.link
            id={"edit-access-group-#{group.id}"}
            phx-click={show_modal("access-group-form-modal#{group.id}")}
            class="font-semibold leading-6 text-zinc-900 hover:text-zinc-700 hover:underline"
          >
            <.icon name="hero-pencil-solid" class="h-4 w-4" />
            {gettext("Edit")}
          </.link>

          <!-- Permissions button -->
          <.link
            id={"access-group-permissions-#{group.id}"}
            navigate={~p"/accounts/groups/#{group.id}/permissions"}
            class="font-semibold leading-6 text-zinc-900 hover:text-zinc-700 hover:underline"
          >
            <.icon name="hero-shield-check" class="h-4 w-4" />
            {gettext("Permissions")}
          </.link>
        </div>
      </:action>
    </.table>

    <!-- Group edit forms (one per group) -->
    <HelpcenterWeb.Accounts.Groups.GroupForm.form
      :for={group <- @groups}
      actor={@current_user}
      group_id={group.id}
      show_button={false}
      id={group.id}
    />
    """
  end

  def mount(_params, _sessions, socket) do
    socket
    |> maybe_subscribe()
    |> assign_groups()
    |> ok()
  end

  # Event handlers
  def handle_info(_message, socket) do
    socket
    |> assign_groups()
    |> noreply()
  end

  # Helpers
  defp maybe_subscribe(socket) do
    if connected?(socket), do: HelpcenterWeb.Endpoint.subscribe("groups")
    socket
  end

  defp assign_groups(socket) do
    assign(socket, :groups, get_groups(socket.assigns.current_user))
  end

  defp get_groups(actor) do
    Ash.read!(Helpcenter.Accounts.Group, actor: actor)
  end
end
```

### 4. Group Permissions Form

Create a component for managing permissions for a group:

```elixir
defmodule HelpcenterWeb.Accounts.Groups.GroupPermissionForm do
  use HelpcenterWeb, :live_component

  # Component interface
  attr :group_id, :string, required: true
  attr :actor, Helpcenter.Accounts.User, required: true

  def form(assigns) do
    ~H"""
    <.live_component id={@group_id} actor={@actor} module={__MODULE__} group_id={@group_id} />
    """
  end

  # Component implementation
  def render(assigns) do
    ~H"""
    <div id={"access-group-permissions-#{@group_id}"}>
      <form id={"access-group-permission-form-#{@group_id}"} phx-submit="save" phx-target={@myself}>
        <!-- Select all permissions control -->
        <div class="flex justify-between items-center mb-6">
          <label class="flex items-center gap-4 text-sm leading-6 text-zinc-600">
            <input
              type="checkbox"
              id={"select-all-#{@group_id}"}
              phx-hook="SelectAllPermissions"
              data-group-id={@group_id}
              class="rounded border-zinc-300 text-zinc-900 focus:ring-0"
            />
            <span class="font-medium">{gettext("Select All Permissions")}</span>
          </label>
          
          <!-- Save button -->
          <.button type="submit" phx-disable-with={gettext("Saving...")}>
            {gettext("Save Permissions")}
          </.button>
        </div>
        
        <!-- Resource permissions table -->
        <.table id={"permissions-#{@group_id}"} rows={@resources}>
          <:col :let={resource} label={gettext("Resource")}>
            <span class="font-semibold text-zinc-900">
              {resource.name}
            </span>
          </:col>
          <:col :let={resource} label={gettext("Actions")}>
            <div class="flex flex-wrap gap-4">
              <label 
                :for={action <- resource.actions}
                class="flex items-center gap-2 text-sm leading-6 text-zinc-600"
              >
                <input
                  type="checkbox"
                  name={"permissions[#{resource.name}][#{action.name}]"}
                  class="permission-checkbox rounded border-zinc-300 text-zinc-900 focus:ring-0"
                  checked={permission_checked?(action, resource, @permissions)}
                  value="true"
                />
                <span>{action.name}</span>
              </label>
            </div>
          </:col>
        </.table>
      </form>
    </div>
    """
  end

  # Component lifecycle
  def update(%{group_id: group_id, actor: actor} = assigns, socket) do
    socket
    |> assign(assigns)
    |> assign(:resources, get_resources())
    |> assign(:group, get_group(group_id, actor))
    |> assign(:permissions, get_permissions(group_id, actor))
    |> ok()
  end

  # Event handlers
  def handle_event("save", %{"permissions" => permissions_params}, socket) do
    with {:ok, _result} <- save_permissions(socket, permissions_params) do
      socket
      |> put_component_flash(:info, gettext("Permissions Updated"))
      |> noreply()
    else
      _error ->
        socket
        |> put_component_flash(:error, gettext("Error updating permissions"))
        |> noreply()
    end
  end

  # Helper functions
  defp get_resources do
    Helpcenter.permissions()
    |> Enum.group_by(& &1.resource)
    |> Enum.map(fn {resource, actions} ->
      %{
        name: resource,
        actions: Enum.map(actions, & %{name: &1.action})
      }
    end)
    |> Enum.sort_by(& &1.name)
  end

  defp get_group(group_id, actor) do
    Helpcenter.Accounts.Group
    |> Ash.get!(group_id, actor: actor)
  end

  defp get_permissions(group_id, actor) do
    Helpcenter.Accounts.GroupPermission
    |> Ash.Query.filter(group_id == ^group_id)
    |> Ash.read!(actor: actor)
  end

  defp permission_checked?(%{name: action}, %{name: resource}, permissions) do
    Enum.any?(permissions, fn p -> 
      p.action == to_string(action) && p.resource == to_string(resource) 
    end)
  end

  defp save_permissions(socket, permissions_params) do
    # Process permissions and update database
    # Implementation details depend on specific requirements
  end
end
```

## Applying Authorization with Policies

To enforce permissions, add policies to your resources:

```elixir
defmodule Helpcenter.KnowledgeBase.Article do
  use Ash.Resource,
    domain: Helpcenter.KnowledgeBase,
    data_layer: AshPostgres.DataLayer

  # Resource definition...
  
  actions do
    # Action definitions...
  end
  
  # Define authorization policy
  policies do
    # Default policy - deny all
    policy always() do
      forbid_unless(actor_present())
    end
    
    # Create policy
    policy action(:create) do
      authorize_if(Helpcenter.Accounts.Checks.Authorized)
    end
    
    # Read policy
    policy action(:read) do
      authorize_if(Helpcenter.Accounts.Checks.Authorized)
    end
    
    # Update policy
    policy action(:update) do
      authorize_if(Helpcenter.Accounts.Checks.Authorized)
    end
    
    # Destroy policy
    policy action(:destroy) do
      authorize_if(Helpcenter.Accounts.Checks.Authorized)
    end
  end
end
```

## Key Benefits of This Approach

1. **Dynamic Permission Discovery**: No need to hardcode permissions
2. **Flexible Group Management**: Users can belong to multiple groups
3. **Granular Access Control**: Permission based on resource + action
4. **Tenant Isolation**: Permissions respect multi-tenancy boundaries
5. **Owner Override**: Team owners automatically get all permissions
6. **UI Integration**: Complete interface for managing permissions
7. **Performance**: Efficient permission checking with minimal database queries