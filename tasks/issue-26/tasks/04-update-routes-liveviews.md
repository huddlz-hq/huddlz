# Task 4: Update Routes and LiveViews

## Objective
Update all routing and LiveView logic to use slugs instead of UUIDs.

## Implementation Steps

### 1. Update Router (`lib/huddlz_web/router.ex`)
```elixir
# Change from:
live "/groups/:id", GroupLive.Show, :show
live "/groups/:group_id/huddlz/new", HuddlLive.New, :new
live "/groups/:group_id/huddlz/:id", HuddlLive.Show, :show

# To:
live "/groups/:slug", GroupLive.Show, :show
live "/groups/:group_slug/huddlz/new", HuddlLive.New, :new
live "/groups/:group_slug/huddlz/:id", HuddlLive.Show, :show
```

### 2. Update GroupLive.Show (`lib/huddlz_web/live/group_live/show.ex`)
- Change `handle_params` to accept `slug` instead of `id`
- Update `get_group` to use `Ash.get(Group, :get_by_slug, %{slug: slug})`
- Ensure all internal references use slug

### 3. Update GroupLive.Index (`lib/huddlz_web/live/group_live/index.ex`)
- Update link generation to use `group.slug` instead of `group.id`

### 4. Update HuddlLive.New (`lib/huddlz_web/live/huddl_live/new.ex`)
- Change params from `group_id` to `group_slug`
- Load group by slug
- Update any redirects

### 5. Update HuddlLive.Show (`lib/huddlz_web/live/huddl_live/show.ex`)
- Handle `group_slug` parameter if needed
- Update any group references

## Key Changes
- All `~p"/groups/#{group.id}"` → `~p"/groups/#{group.slug}"`
- All `params["id"]` → `params["slug"]`
- All `group_id` in routes → `group_slug`

## Acceptance Criteria
- [ ] Router updated with slug parameters
- [ ] All LiveViews load groups by slug
- [ ] Navigation works with slugs
- [ ] Error handling for invalid slugs
- [ ] No broken routes

## Testing Notes
- Test valid slug navigation
- Test invalid slug (404 behavior)
- Test all group-related flows
- Verify huddl creation under groups still works