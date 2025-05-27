# Task 2: Update Group Resource

## Objective
Add slug attribute to the Group resource with proper validations and actions.

## Implementation Steps

1. **Add Slug Attribute**
   In `lib/huddlz/communities/group.ex`, add to attributes block:
   ```elixir
   attribute :slug, :string do
     allow_nil? false
     public? true
   end
   ```

2. **Add Unique Identity**
   In identities block:
   ```elixir
   identity :unique_slug, [:slug]
   ```

3. **Update Actions**
   - Add `:slug` to `create_group` action's accept list
   - Add `:slug` to `update_details` action's accept list

4. **Add Slug Generation Change**
   Create a new change module for automatic slug generation on create

5. **Add Read Action for Slug**
   ```elixir
   read :get_by_slug do
     argument :slug, :string do
       allow_nil? false
     end
     
     get? true
     filter expr(slug == ^arg(:slug))
   end
   ```

## Acceptance Criteria
- [ ] Slug attribute added to resource
- [ ] Unique identity configured
- [ ] Actions accept slug field
- [ ] get_by_slug action works
- [ ] Resource compiles without errors

## Notes
- Slug must be globally unique
- Will be auto-generated but can be overridden
- No need for complex validation - Ash handles uniqueness