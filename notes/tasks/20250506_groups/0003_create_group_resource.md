# Task: Create Group Resource

## Context
- Part of feature: Group Management
- Sequence: Task 3 of 8
- Purpose: Define the core Group resource with all necessary attributes and relationships

## Task Boundaries
- In scope: 
  - Group schema definition with all required attributes
  - Relationships setup (owner, members)
  - Access control policies
  - Basic CRUD actions
- Out of scope: 
  - Migration generation (separate task)
  - UI implementation
  - Integration with huddlz

## Current Status
- Status: In progress
- Blockers: None
- Current activity: Fixing Group resource tests

## Requirements Analysis
- Create a Group resource using Ash Framework in the Communities domain
- Include fields: name, description, location, image_url, is_public
- Establish relationships:
  - belongs_to :owner (User) - The user who created the group
  - many_to_many :members (User) - Users who are members of the group
- Set up proper identities and constraints
- Define appropriate access policies
- Implement necessary CRUD actions

## Implementation Plan
- Create the Group resource module in lib/huddlz/communities/group.ex
- Define attributes and relationships
- Implement basic actions (create, read, update, destroy)
- Add specialized actions for managing group membership
- Set up access policies to restrict group creation to admins and verified users

## Implementation Checklist
1. Create the Group resource module file
2. Define basic attributes (name, description, location, image_url, is_public)
3. Add timestamp attributes (created_at, updated_at)
4. Set up owner relationship (belongs_to User)
5. Set up members relationship (many_to_many User)
6. Create the join resource for group memberships (GroupMember)
7. Implement standard CRUD actions
8. Add specialized actions for membership management
9. Set up appropriate access policies
10. Define identities for uniqueness constraints

## Related Files
- lib/huddlz/communities/group.ex (to be created)
- lib/huddlz/communities/group_member.ex (to be created for many-to-many)
- lib/huddlz/communities.ex (to update with new resources)

## Code Examples

### Group Resource
```elixir
defmodule Huddlz.Communities.Group do
  use Ash.Resource,
    otp_app: :huddlz,
    domain: Huddlz.Communities,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "groups"
    repo Huddlz.Repo
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
      constraints min_length: 3, max_length: 100
    end

    attribute :description, :string do
      allow_nil? true
    end

    attribute :location, :string do
      allow_nil? true
    end

    attribute :image_url, :string do
      allow_nil? true
    end

    attribute :is_public, :boolean do
      allow_nil? false
      default true
    end

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :owner, Huddlz.Accounts.User do
      attribute_type :uuid
      allow_nil? false
      primary_key? false
    end

    many_to_many :members, Huddlz.Accounts.User do
      through Huddlz.Communities.GroupMember
      source_attribute_on_join_resource :group_id
      destination_attribute_on_join_resource :user_id
    end
  end

  actions do
    defaults [:create, :read, :update, :destroy]
    
    create :create_group do
      description "Create a new group"
      accept [:name, :description, :location, :image_url, :is_public]
      
      argument :owner_id, :uuid do
        allow_nil? false
      end
      
      change manage_relationship(:owner_id, :owner, type: :append)
    end
  end

  identities do
    identity :unique_name, [:name]
  end
end
```

### Group Member Join Resource
```elixir
defmodule Huddlz.Communities.GroupMember do
  use Ash.Resource,
    otp_app: :huddlz,
    domain: Huddlz.Communities,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "group_members"
    repo Huddlz.Repo
  end

  actions do
    defaults [:create, :read, :destroy]
  end

  attributes do
    uuid_primary_key :id
    
    attribute :role, :string do
      allow_nil? false
      default "member"
      constraints one_of: ["member", "admin"]
    end
    
    create_timestamp :created_at
  end

  relationships do
    belongs_to :group, Huddlz.Communities.Group do
      attribute_type :uuid
      allow_nil? false
      primary_key? false
    end
    
    belongs_to :user, Huddlz.Accounts.User do
      attribute_type :uuid
      allow_nil? false
      primary_key? false
    end
  end

  identities do
    identity :unique_group_user, [:group_id, :user_id]
  end
end
```

## Definition of Done
- Group and GroupMember resources are fully defined
- All required attributes and relationships are set up
- Actions for CRUD and membership management are implemented
- Access policies are properly configured
- Module compiles successfully

## Progress Tracking
1. Task preparation - [May 17, 2025]

## Session Log
- [May 17, 2025] Starting implementation of this task...
- [May 17, 2025] Group and GroupMember resource files already created
- [May 17, 2025] Fixed compilation issues (action_type(:all) not supported, duplicate search methods)
- [May 17, 2025] Created tests for Group and GroupMember resources
- [May 17, 2025] Working on fixing tests to match Ash patterns

## Next Task
- Next task: 0004_generate_group_migrations
- Only proceed to the next task after this task is complete and verified