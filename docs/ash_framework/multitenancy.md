# Ash Framework: Multi-Tenancy & Team Relationships

This document covers how to implement multi-tenancy in Ash Framework applications, with a focus on:

- Setting up multi-tenant resources
- Managing team/tenant relationships with users
- Automating tenant creation and relationships

## Multi-Tenancy with Ash Framework

### Understanding Multi-Tenancy in Ash

Multi-tenancy is a software architecture where a single instance of an application serves multiple customers (tenants). Each tenant's data is isolated and invisible to other tenants. Ash Framework provides built-in support for multi-tenancy through several mechanisms:

1. **Context-Based Strategy**: Uses the tenant identifier from the context to scope queries
2. **Schema-Based Isolation**: Uses PostgreSQL schemas for complete database-level isolation
3. **Custom ToTenant Implementation**: Allows custom tenant resolution logic

### Setting Up the Tenant Resource

The first step is creating a resource to represent tenants (often called teams or organizations):

```elixir
defmodule Helpcenter.Accounts.Team do
  use Ash.Resource,
    domain: Helpcenter.Accounts,
    data_layer: AshPostgres.DataLayer

  # Implement Ash.ToTenant to control how the tenant is determined
  defimpl Ash.ToTenant do
    def to_tenant(resource, %{:domain => domain, :id => id}) do
      if Ash.Resource.Info.data_layer(resource) == AshPostgres.DataLayer &&
           Ash.Resource.Info.multitenancy_strategy(resource) == :context do
        # Use domain as the PostgreSQL schema name
        domain
      else
        # Otherwise use ID
        id
      end
    end
  end

  postgres do
    table "teams"
    repo Helpcenter.Repo

    # Configure tenant management for PostgreSQL schemas
    manage_tenant do
      template ["", :domain]  # Schema naming pattern
      create? true            # Create schemas automatically
      update? false           # Don't rename schemas on update
    end
  end

  actions do
    default_accept [:name, :domain, :description]
    defaults [:create, :read]
  end

  attributes do
    uuid_v7_primary_key :id
    attribute :name, :string, allow_nil?: false, public?: true
    attribute :domain, :string, allow_nil?: false, public?: true
    attribute :description, :string, allow_nil?: true, public?: true

    timestamps()
  end

  # Relationships (added later)
  relationships do
    belongs_to :owner, Helpcenter.Accounts.User do
      source_attribute :owner_user_id
    end

    many_to_many :users, Helpcenter.Accounts.User do
      through Helpcenter.Accounts.UserTeam
      source_attribute_on_join_resource :team_id
      destination_attribute_on_join_resource :user_id
    end
  end
end
```

### Configuring the Repository for Multi-Tenancy

Add a function to list all tenants for migrations:

```elixir
# In lib/helpcenter/repo.ex
@doc """
Used by migrations --tenants to list all tenants, create related schemas, and migrate them.
"""
def all_tenants do
  for tenant <- Ash.read!(Helpcenter.Accounts.Team) do
    tenant.domain
  end
end
```

### Creating a Join Resource for Users and Teams

To support users belonging to multiple teams, create a join resource:

```elixir
defmodule Helpcenter.Accounts.UserTeam do
  use Ash.Resource,
    domain: Helpcenter.Accounts,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "user_teams"
    repo Helpcenter.Repo
  end

  resource do
    require_primary_key? false
  end

  actions do
    default_accept [:user_id, :team_id]
    defaults [:create, :read, :update, :destroy]
  end

  attributes do
    uuid_v7_primary_key :id
    timestamps()
  end

  relationships do
    belongs_to :user, Helpcenter.Accounts.User do
      source_attribute :user_id
    end

    belongs_to :team, Helpcenter.Accounts.Team do
      source_attribute :team_id
    end
  end

  identities do
    identity :unique_user_team, [:user_id, :team_id]
  end
end
```

### Making Resources Multi-Tenant Aware

Update all resources that should be tenant-specific by adding the `multitenancy` block:

```elixir
defmodule Helpcenter.KnowledgeBase.Category do
  use Ash.Resource,
    domain: Helpcenter.KnowledgeBase,
    data_layer: AshPostgres.DataLayer,
    notifiers: Ash.Notifier.PubSub

  # Make this resource multi-tenant
  multitenancy do
    strategy :context
  end

  # Rest of resource definition...
end
```

This tells Ash that this resource is tenant-specific and should use the context strategy to determine the current tenant.

### Updating User Resource for Multi-Tenancy

Add current team tracking and teams relationship to the User resource:

```elixir
# In the User resource
attributes do
  # Other existing attributes
  
  attribute :current_team, :string do
    description "The current team the user is accessing the app with"
  end
end

relationships do
  many_to_many :teams, Helpcenter.Accounts.Team do
    through Helpcenter.Accounts.UserTeam
    source_attribute_on_join_resource :user_id
    destination_attribute_on_join_resource :team_id
  end
end
```

### Generating and Running Multi-Tenant Migrations

Generate migrations for the new multi-tenant structure:

```bash
mix ash_postgres.generate_migrations add_multitenancy_tables
mix ash_postgres.migrate
```

This creates the necessary tables and schema structure for multi-tenancy.

### Working with Multi-Tenant Resources

When working with multi-tenant resources, you must provide the tenant:

```elixir
# Create a team
user = create_user()
team = Ash.create!(Helpcenter.Accounts.Team, %{
  name: "Team 1",
  domain: "team_1",
  owner_user_id: user.id
})

# Create a category under a specific tenant
attrs = %{
  name: "Billing",
  slug: "billing",
  description: "Billing issues"
}

{:ok, category} =
  Helpcenter.KnowledgeBase.Category
  |> Ash.Changeset.for_create(:create, attrs, tenant: team.domain)
  |> Ash.create()
```

The `tenant:` option specifies which tenant's schema should store the data.

### Updating Existing Code for Multi-Tenancy

Existing code that creates or queries multi-tenant resources needs to be updated to include the tenant. For example, the Slugify change:

```elixir
defmodule Helpcenter.Changes.Slugify do
  use Ash.Resource.Change

  def change(changeset, _opts, context) do
    if changeset.action_type == :create do
      changeset
      |> Ash.Changeset.force_change_attribute(:slug, generate_slug(changeset, context))
    else
      changeset
    end
  end

  # Pass context to count_similar_slugs
  defp generate_slug(%{attributes: %{name: name}} = changeset, context) when not is_nil(name) do
    slug = get_slug_from_name(name)

    case count_similar_slugs(changeset, slug, context) do
      {:ok, 0} -> slug
      {:ok, count} -> "#{slug}-#{count}"
      {:error, error} -> raise error
    end
  end

  # Other helper functions...

  # Include context in the query
  defp count_similar_slugs(changeset, slug, context) do
    require Ash.Query

    changeset.resource
    |> Ash.Query.filter(slug == ^slug)
    |> Ash.count(Ash.Context.to_opts(context))
  end
end
```

## Automating Relationships in Multi-Tenant Applications

This section covers how to automate relationships between users and teams/tenants in an Ash Framework application, focusing on automatically linking users to teams and creating personal teams.

### The Automation Goals

In multi-tenant applications, there are several common automation requirements:

1. **Team-Owner Association**: Automatically link a team to its owner when created
2. **Current Team Setting**: Set the user's current_team field when a team is created
3. **Personal Team Creation**: Create a personal team for each new user upon registration

Using a test-driven approach helps ensure these automations work correctly.

### Test-Driven Approach to Team-User Relationships

Start by defining tests that describe the expected behavior:

```elixir
defmodule Helpcenter.Accounts.TeamTest do
  use HelpcenterWeb.ConnCase, async: false
  require Ash.Query

  describe "Team tests" do
    test "User team can be created" do
      # Create a user
      user = create_user()
      
      # Create a team with the user as owner
      team_attrs = %{name: "Team 1", domain: "team_1", owner_user_id: user.id}
      {:ok, team} = Ash.create(Helpcenter.Accounts.Team, team_attrs)

      # Verify the team was created correctly
      assert Helpcenter.Accounts.Team
             |> Ash.Query.filter(domain == ^team.domain)
             |> Ash.Query.filter(owner_user_id == ^team.owner_user_id)
             |> Ash.exists?()

      # Verify the user's current_team was set
      assert Helpcenter.Accounts.User
             |> Ash.Query.filter(id == ^user.id)
             |> Ash.Query.filter(current_team == ^team.domain)
             |> Ash.exists?(authorize?: false)

      # Verify the user is linked to the team
      assert Helpcenter.Accounts.User
             |> Ash.Query.filter(id == ^user.id)
             |> Ash.Query.filter(teams.id == ^team.id)
             |> Ash.exists?(authorize?: false)
    end
  end
end
```

### Implementing Team-Owner Association

#### 1. Custom Create Action with Changes

Update the Team resource to use custom changes during creation:

```elixir
# In lib/helpcenter/accounts/team.ex
actions do
  default_accept [:name, :domain, :description, :owner_user_id]
  defaults [:read]

  create :create do
    primary? true  # Make this the default create action
    change Helpcenter.Accounts.Team.Changes.AssociateUserToTeam
    change Helpcenter.Accounts.Team.Changes.SetOwnerCurrentTeam
  end
end
```

#### 2. Associate User to Team Change

Create a change to link the owner to the team via the join table:

```elixir
# lib/helpcenter/accounts/team/changes/associate_user_to_team.ex
defmodule Helpcenter.Accounts.Team.Changes.AssociateUserToTeam do
  @moduledoc """
  Links a user to a team via the user_teams relationship,
  enabling team listing for the owner.
  """
  use Ash.Resource.Change
  
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_action(changeset, &associate_owner_to_team/2)
  end

  defp associate_owner_to_team(_changeset, team) do
    params = %{user_id: team.owner_user_id, team_id: team.id}
    
    {:ok, _user_team} =
      Helpcenter.Accounts.UserTeam
      |> Ash.Changeset.for_create(:create, params)
      |> Ash.create()
      
    {:ok, team}
  end
end
```

This change:
- Uses `after_action` to run after team creation is complete
- Creates an entry in the UserTeam join table
- Returns `{:ok, team}` to indicate success

#### 3. Set Owner's Current Team Change

Create a change to update the owner's current_team field:

```elixir
# lib/helpcenter/accounts/team/changes/set_owner_current_team.ex
defmodule Helpcenter.Accounts.Team.Changes.SetOwnerCurrentTeam do
  use Ash.Resource.Change
  
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_action(changeset, &set_owner_current_team/2)
  end

  defp set_owner_current_team(_changeset, team) do
    opts = [authorize?: false]
    
    {:ok, _user} =
      Helpcenter.Accounts.User
      |> Ash.get!(team.owner_user_id, opts)
      |> Ash.Changeset.for_update(:set_current_team, %{team: team.domain})
      |> Ash.update(opts)

    {:ok, team}
  end
end
```

This change:
- Uses `after_action` to run after team creation
- Updates the owner's user record with the new team domain
- Uses `authorize?: false` to bypass authentication policies for this internal operation

#### 4. Add Set Current Team Action to User Resource

Add a supporting action to the User resource:

```elixir
# In lib/helpcenter/accounts/user.ex
actions do
  # Other actions...
  
  update :set_current_team do
    description "Sets the user's current team."
    argument :team, :string, allow_nil?: false, sensitive?: false
    change set_attribute(:current_team, arg(:team))
  end
end
```

This action:
- Accepts a `team` argument (the team domain)
- Sets the `current_team` attribute to this value

### Automating Personal Team Creation on User Registration

#### 1. Test for Personal Team Creation

Create a test to verify automatic personal team creation:

```elixir
defmodule Helpcenter.Accounts.UserTest do
  use HelpcenterWeb.ConnCase, async: false
  require Ash.Query

  describe "User tests:" do
    test "User creation - creates personal team automatically" do
      # Create a new user
      user_params = %{
        email: "john.tester@example.com",
        password: "12345678",
        password_confirmation: "12345678"
      }

      user =
        Ash.create!(
          Helpcenter.Accounts.User,
          user_params,
          action: :register_with_password,
          authorize?: false
        )

      # Verify user has a current_team (personal team)
      refute Helpcenter.Accounts.User
             |> Ash.Query.filter(id == ^user.id)
             |> Ash.Query.filter(email == ^user_params.email)
             |> Ash.Query.filter(is_nil(current_team))
             |> Ash.exists?(authorize?: false)
    end
  end
end
```

#### 2. Create a Notifier for Personal Team Creation

Use Ash's notifier system to react to user registration:

```elixir
# lib/helpcenter/accounts/user/notifiers/create_personal_team_notification.ex
defmodule Helpcenter.Accounts.User.Notifiers.CreatePersonalTeamNotification do
  alias Ash.Notifier.Notification
  use Ash.Notifier

  def notify(%Notification{data: user, action: %{name: :register_with_password}}) do
    create_personal_team(user)
  end

  def notify(%Notification{} = _notification), do: :ok

  defp create_personal_team(user) do
    # Create unique domain by counting existing teams
    team_count = Ash.count!(Helpcenter.Accounts.Team) + 1

    team_attrs = %{
      name: "Personal Team",
      domain: "personal_team_#{team_count}",
      owner_user_id: user.id
    }

    Ash.create!(Helpcenter.Accounts.Team, team_attrs)
  end
end
```

This notifier:
- Listens specifically for the `:register_with_password` action
- Creates a personal team with the user as owner
- Uses a counter to ensure unique team domains

#### 3. Register the Notifier with the User Resource

Add the notifier to the User resource:

```elixir
# In lib/helpcenter/accounts/user.ex
defmodule Helpcenter.Accounts.User do
  use Ash.Resource,
    otp_app: :helpcenter,
    domain: Helpcenter.Accounts,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshAuthentication],
    data_layer: AshPostgres.DataLayer,
    
    # Register notifier for post-registration actions
    notifiers: [Helpcenter.Accounts.User.Notifiers.CreatePersonalTeamNotification]
    
  # Rest of resource definition...
end
```

## Key Concepts in Multi-Tenancy and Relationship Automation

### Multi-Tenancy Concepts

1. **Tenant Strategy**: Using the `:context` strategy for tenant identification
2. **Schema-Based Isolation**: Using PostgreSQL schemas for complete data isolation
3. **Tenant Resolution**: Custom tenant resolution via the `Ash.ToTenant` protocol
4. **Many-to-Many User-Team Relationship**: Supporting users belonging to multiple teams

### Relationship Automation Concepts

1. **after_action Hooks**: Using `Ash.Changeset.after_action/2` to trigger code after a resource action completes
2. **Resource Changes**: Custom change modules with the `Ash.Resource.Change` behavior
3. **Notifiers**: Using `Ash.Notifier` to react to resource events without modifying the original resource
4. **Policy Bypassing**: Using `authorize?: false` for internal operations when appropriate
5. **Test-Driven Development**: Writing tests first to define the expected behavior

## Best Practices

### Multi-Tenancy Best Practices

1. **Always Include Tenant**: Always provide the tenant when working with multi-tenant resources
2. **Use Domain for Schema Names**: Use simple, URL-friendly identifiers for schema names
3. **Test Tenant Isolation**: Verify that tenants cannot access each other's data
4. **Update Existing Code**: Remember to update all existing code to be tenant-aware
5. **Consider Non-Tenant Resources**: Some resources (like Users) may not be tenant-specific
6. **Optimize Migrations**: Use the --tenants flag for migrations to update all tenant schemas

### Automating Relationships Best Practices

1. **Extract Logic to Changes**: Use changes for complex logic rather than embedding it in actions
2. **Use Notifiers for Cross-Resource Effects**: When an action on one resource should affect another resource
3. **Consider Policy Implications**: Be careful with policy bypassing and only use when necessary
4. **Test Both Success and Failure Cases**: Ensure automations don't cause unexpected side effects
5. **Favor Extension Over Modification**: Use notifiers and changes to extend behavior rather than directly modifying resource actions
6. **Use Atomic Operations**: Ensure relationship changes don't leave data in inconsistent states