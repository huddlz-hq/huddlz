# Task 5: Update UI Forms

## Objective
Add slug fields to group creation and editing forms with appropriate behavior.

## Implementation Steps

### 1. Update GroupLive.New (`lib/huddlz_web/live/group_live/new.ex`)

**Add slug field to form:**
- Add slug input field below name field
- Implement JavaScript hook for auto-slug generation
- Slug updates automatically as user types name
- Allow manual override of generated slug

**Form structure:**
```elixir
<.input field={f[:name]} type="text" label="Group Name" phx-keyup="update_slug" />
<.input field={f[:slug]} type="text" label="URL Slug" 
  placeholder="my-group-name" 
  pattern="[a-z0-9-]+"
  title="Only lowercase letters, numbers, and hyphens allowed" />
<p class="text-sm text-gray-600 mt-1">
  Your group will be available at: /groups/{slug}
</p>
```

**Handle slug generation:**
```elixir
def handle_event("update_slug", %{"value" => name}, socket) do
  slug = Slug.slugify(name)
  {:noreply, assign(socket, suggested_slug: slug)}
end
```

### 2. Update Group Edit Form

**Add slug field with warning:**
- Show current slug
- Allow editing
- Display warning about breaking URLs

```elixir
<.input field={f[:slug]} type="text" label="URL Slug" />
<p class="text-sm text-yellow-600 mt-1">
  ⚠️ Warning: Changing the slug will break existing links to this group
</p>
```

### 3. Handle Form Submission

**Validation errors:**
- Display clear error message on slug collision
- "This slug is already taken. Please choose a different one."

**Success handling:**
- Redirect to new slug-based URL after creation/update

## JavaScript Hook (Optional Enhancement)

```javascript
Hooks.SlugInput = {
  mounted() {
    const nameInput = document.getElementById("group_name")
    const slugInput = this.el
    
    nameInput.addEventListener("input", (e) => {
      if (!slugInput.dataset.manual) {
        // Only auto-update if user hasn't manually edited
        this.pushEvent("generate_slug", {name: e.target.value})
      }
    })
    
    slugInput.addEventListener("input", () => {
      slugInput.dataset.manual = "true"
    })
  }
}
```

## Acceptance Criteria
- [ ] Slug field in create form
- [ ] Auto-generation works on create
- [ ] Manual override possible
- [ ] Slug field in edit form
- [ ] Warning shown when editing slug
- [ ] Validation errors display clearly
- [ ] Forms submit successfully
- [ ] Redirects use new slugs

## UI/UX Notes
- Keep slug field close to name field
- Show live preview of final URL
- Clear validation messages
- Warning for slug changes is prominent
- Slug format requirements are clear