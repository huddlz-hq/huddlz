# Ash Framework Documentation

This directory contains comprehensive documentation on the Ash Framework for use in the huddlz project. The documentation has been organized into topic-specific files for easier navigation and reference.

## Attribution

The initial version of this documentation was inspired by and based on the excellent Ash Framework blog series by [Lambert Kamaro](https://medium.com/@lambert.kamaro). His detailed explanations and practical examples provided the foundation for much of this knowledge base.

## Table of Contents

- [Resource Workflow](resource_workflow.md) - **IMPORTANT**: The correct workflow for developing resources
  - Domain definition first
  - Resource definition next
  - Code generation last
  - Best practices and common mistakes

- [Relationships](relationships.md) - How to work with different relationship types in Ash
  - Has Many, Belongs To, Has One, Many-to-Many relationships
  - Creating, reading, and managing related data
  - Filtering with relationships
  - Deleting related records

- [Phoenix Integration](phoenix_integration.md) - Integrating Ash with Phoenix web framework
  - Using Ash in Phoenix controllers
  - CRUD operations with Phoenix LiveView
  - AshPhoenix Form integration
  - Real-time features with Ash.Notifications

- [Query Preparations](query_preparations.md) - Creating reusable query logic
  - Local and global preparations
  - Reusable preparation modules
  - Composable preparation patterns

- [Reusable Changes](reusable_changes.md) - Creating reusable change logic for create/update
  - Change module patterns
  - Conditional changes
  - Hooks and lifecycle integration
  - Change options

- [Multi-tenancy](multitenancy.md) - Implementing multi-tenant applications with Ash
  - Setting up multi-tenant resources
  - Managing team/tenant relationships
  - Automating tenant creation

- [Authentication](authentication.md) - Implementing authentication with Ash
  - Setting up Ash Authentication
  - User resource configuration
  - Router integration
  - Authentication strategies
  - Customizing the auth flow

- [Access Control](access_control.md) - Implementing permissions and authorization
  - Role-based access control (RBAC)
  - Dynamic permission discovery
  - Authorization checks
  - UI for permission management

- [Testing](testing.md) - Testing Ash Framework applications
  - Setting up the testing environment
  - Testing authentication and protected routes
  - Creating reusable test helpers
  - Testing LiveView interactions

## External Resources

For official Ash documentation and additional resources, visit:

- [Ash Framework Official Documentation](https://hexdocs.pm/ash/get-started.html)
- [Ash on GitHub](https://github.com/ash-project/ash)
- [Ash Framework Community](https://elixirforum.com/tag/ash-framework)