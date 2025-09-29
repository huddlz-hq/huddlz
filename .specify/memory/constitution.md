<!-- Sync Impact Report
Version change: 1.0.0 (initial creation)
Modified principles: N/A (initial creation)
Added sections: All sections newly created
Removed sections: N/A (initial creation)
Templates requiring updates:
- ✅ plan-template.md (Constitution Check gates need alignment)
- ⚠ spec-template.md (pending review)
- ⚠ tasks-template.md (pending review for task categorization)
- ⚠ commands/*.md (pending review)
Follow-up TODOs:
- RATIFICATION_DATE: Set to today as initial adoption
-->

# Huddlz Constitution

## Core Principles

### I. Resource-First Development with Ash
Every feature in this project starts with defining Ash resources. Resources must be created and configured before any implementation begins. The resource definition drives the entire development flow - from database migrations to API endpoints. No feature development can proceed without first establishing the resource structure in Ash.

**Rationale**: Ash provides declarative, extensible domain modeling that ensures consistency across the entire stack. Starting with resources guarantees that our domain logic is properly structured before implementation begins.

### II. Test-After-Resource Pattern
Tests are written immediately after resource generation and before any other implementation. Every resource action MUST have comprehensive tests that exercise both the action logic and all associated permissions. The test suite validates the complete permissions matrix for each action.

**Rationale**: While traditional TDD writes tests first, Ash's declarative nature requires the resource to exist before meaningful tests can be written. This modified approach maintains test discipline while working within Ash's constraints.

### III. Comprehensive Permissions Matrix
Every action on every resource MUST have a well-thought-out permissions matrix. Permissions are not an afterthought but a core design consideration. Each action test must exercise all permission scenarios - authorized access, unauthorized access, and edge cases.

**Rationale**: Security and authorization are fundamental to application integrity. Testing permissions alongside functionality ensures that security is never compromised during development.

### IV. Multi-Endpoint Planning
When planning features and actions, always consider whether they will need JSON API endpoints, GraphQL endpoints, or MCP tool endpoints. This consideration must happen during the planning phase, not as an afterthought during implementation.

**Rationale**: Ash supports multiple API interfaces natively. Planning for multiple endpoints ensures consistent behavior across all access patterns and prevents rework when additional interfaces are needed.

### V. Migration-Driven Schema Evolution
Database schema changes only occur through Ash-generated migrations. Manual schema modifications are forbidden. The flow is always: modify resource → generate migration → run migration → verify with tests.

**Rationale**: Ash's migration generation ensures that the database schema perfectly matches the resource definitions, preventing drift between code and database.

## Development Workflow

### Resource Development Cycle
1. Define or modify Ash resource with actions and attributes
2. Generate migrations using Ash tooling
3. Write comprehensive tests for all new/modified actions
4. Ensure tests exercise complete permissions matrix
5. Run tests to verify they fail appropriately
6. Implement necessary business logic
7. Verify all tests pass
8. Consider and document API endpoint requirements

### Testing Requirements
- Every action MUST have at least one test
- Permission tests are mandatory for all actions
- Tests must cover success paths and failure paths
- Integration tests should verify cross-resource interactions
- API endpoint tests must validate all supported formats (JSON, GraphQL, MCP as applicable)

## Quality Standards

### Code Review Gates
- Resource changes require migration review
- All actions must have corresponding tests
- Permissions matrix must be documented and tested
- API endpoint consistency must be verified across formats

### Documentation Standards
- Resources must have clear documentation of their purpose
- Actions must document their expected behavior and permissions
- API endpoints must specify their format and authentication requirements

## Governance

### Constitution Authority
This constitution supersedes all other development practices. All development must comply with these principles. Deviations require explicit documentation and justification in the Complexity Tracking section of planning documents.

### Amendment Process
- Amendments require documentation of the change and its rationale
- Migration plan must be provided for any breaking changes
- All dependent templates and documentation must be updated

### Compliance Verification
- All PRs must verify constitutional compliance
- Code reviews must check for resource-first development
- Test coverage reports must show action and permission coverage
- Use CLAUDE.md for runtime development guidance

**Version**: 1.0.0 | **Ratified**: 2025-09-29 | **Last Amended**: 2025-09-29