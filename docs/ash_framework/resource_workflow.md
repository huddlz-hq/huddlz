# Ash Framework Resource Development Workflow

This document outlines the correct workflow for developing new resources using Ash Framework in the huddlz project.

## Important Sequence

**ALWAYS follow this exact sequence when creating new resources:**

1. **Define Domain First**: Create or update the domain module
2. **Create Resource Next**: Define the resource structure with attributes, relationships, and actions
3. **Generate Last**: Use either in-memory generation or `mix ash.codegen` to create migrations

Skipping steps or performing them out of order can lead to inconsistent data models, broken functionality, or lost work.

## 1. Domain Definition

Domains provide the boundary for a set of related resources. They represent a cohesive conceptual area of the application.

```elixir
defmodule Huddlz.Communities do
  use Ash.Domain,
    otp_app: :huddlz

  resources do
    # Resources will be listed here
  end
end
```

**Key considerations:**
- Design domains around conceptual relationships between resources
- Update application configuration to register the domain
- Choose domain names that reflect their conceptual purpose

## 2. Resource Definition

Resources define the data model, relationships, actions, and policies.

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
    # Define attributes here
  end

  relationships do
    # Define relationships here
  end

  actions do
    # Define actions here
  end

  # Add policies, identities, calculations as needed
end
```

**Key considerations:**
- Define all attributes, relationships, and actions before generating migrations
- Set up policies to control access to the resource
- Establish identities for uniqueness constraints
- Use descriptive names for attributes and relationships

## 3. Code Generation

Only after the domain and resource are fully defined should you generate migrations.

```bash
# Generate migrations based on resource changes
mix ash.codegen communities_changes

# IMPORTANT: Always use ash.migrate to run migrations, not ecto.migrate
mix ash.migrate
```

**Never modify existing migrations** - always generate new ones to make changes.

## Testing the Workflow

After completing the workflow, verify your implementation:

1. Check that the domain includes the new resource
2. Compile the application to ensure there are no errors
3. Run tests to verify functionality
4. Generate migrations if needed using `mix ash.codegen`
5. Apply migrations to update the database schema using `mix ash.migrate` (NOT `mix ecto.migrate`)

## Common Mistakes to Avoid

- **Creating migrations before finalizing the resource** - This leads to multiple migrations for the same change
- **Modifying existing migrations** - Always create new migrations instead
- **Skipping the domain definition** - Every resource must belong to a domain
- **Incomplete resource definitions** - Define all components (attributes, relationships, actions) before generation

## Best Practices

- Group related resources in the same domain
- Create join resources for many-to-many relationships
- Use consistent naming conventions
- Write tests for resource functionality
- Document the purpose of each resource and its relationships

Following this workflow ensures a consistent, maintainable, and properly functioning application.