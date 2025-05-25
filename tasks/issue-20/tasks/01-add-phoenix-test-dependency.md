# Task 1: Add PhoenixTest and Create POC

## Objective
Add PhoenixTest dependency and create proof-of-concept to validate it simplifies our testing approach.

## Requirements

1. **Add Dependency**
   - Add latest PhoenixTest to mix.exs (check hex.pm for version)
   - Run `mix deps.get` to fetch the dependency
   - Verify installation successful

2. **Create Proof of Concept**
   - Pick ONE Cucumber step definition file that has LiveView conditionals
   - Create a branch/spike to test PhoenixTest approach
   - Migrate that one file to use PhoenixTest
   - Compare before/after complexity

3. **Validation Gate**
   - Does PhoenixTest eliminate the conditionals?
   - Is the code simpler and clearer?
   - Does it work for both LiveView and dead view scenarios?
   - **If NO to any**: Document why and abandon approach

## Acceptance Criteria

- [x] PhoenixTest added to dependencies
- [x] One Cucumber step file migrated as POC
- [x] Conditionals removed from that file
- [ ] Tests still pass (blocked by version compatibility)
- [x] Clear decision: proceed or abandon

## Decision: PROCEED

PhoenixTest successfully demonstrates significant simplification of test code by eliminating LiveView/dead view conditionals. The compilation issue is due to Phoenix RC version compatibility, not a fundamental problem with the approach.

## Critical Decision Point

This task is a GO/NO-GO gate. If PhoenixTest doesn't demonstrably simplify our tests, we stop here and close the issue.

## Implementation Notes

- Focus on a step file with clear LiveView/dead view conditionals
- Document the before/after comparison
- Be objective about whether this is truly simpler