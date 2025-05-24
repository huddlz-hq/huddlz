# Session Notes: Huddl Display Implementation
**Date**: 2025-05-24
**Topic**: Understanding event display patterns in Phoenix application

## Goals
- Analyze existing component patterns for displaying data
- Understand Huddl resource structure and fields
- Identify styling approach and CSS framework usage
- Find any existing huddl display implementations

## Activities

### 1. Component Pattern Analysis
Examined core components in `/lib/huddlz_web/components/core_components.ex`:
- Framework: Phoenix LiveView with Tailwind CSS + daisyUI
- Key components: flash, button, input, header, table, list, icon
- Styling approach: Utility-first with daisyUI component classes

### 2. Display Pattern Review
Analyzed `group_live/show.ex` as reference for display patterns:
- Uses Layouts.app wrapper for consistent layout
- Implements header component with title, subtitle (badges), and actions
- Displays data in sections with prose styling
- Uses grid layouts for organizing information
- Implements member access control based on user verification status

### 3. Huddl Resource Structure
From `/lib/huddlz/communities/huddl.ex`, key fields for display:
- **Basic Info**: title, description, thumbnail_url
- **Timing**: starts_at, ends_at, status (calculated)
- **Event Details**: event_type (in_person/virtual/hybrid), physical_location, virtual_link
- **Metadata**: is_private, rsvp_count, creator, group
- **Calculated**: status (upcoming/in_progress/completed), visible_virtual_link

### 4. Existing Huddl Display
Found `huddl_live.ex` with list view implementation:
- Shows huddl cards with thumbnail, title, description, and timing
- Uses responsive flex layout with image on left
- Displays status badge overlaid on thumbnail
- Includes search functionality
- Missing: Individual huddl show page

### 5. Routing Structure
From router.ex:
- List view: `/` (root path)
- Create new: `/groups/:group_id/huddlz/new`
- Missing: Individual huddl show route (e.g., `/groups/:group_id/huddlz/:id`)

## Decisions
1. Follow existing component patterns using daisyUI classes
2. Implement show page similar to group show structure
3. Use calculated fields for dynamic display (status, visible_virtual_link)
4. Apply same access control patterns as groups

## Outcomes
### Key Findings
1. **Component Patterns**:
   - Use `<.header>` for page titles with actions
   - Use badges for status indicators
   - Grid layouts for detail sections
   - Prose class for content areas

2. **Styling Approach**:
   - Tailwind utilities for layout/spacing
   - daisyUI classes: btn, badge, card, alert
   - Color scheme: base-*, primary, secondary
   - Responsive with md: breakpoints

3. **Missing Components**:
   - No individual huddl show page/route
   - No event-specific components (RSVP, attendee list)
   - No event type indicators (virtual/in-person/hybrid)

4. **Access Control Pattern**:
   - Check group membership/visibility first
   - Use actor-based authorization in Ash queries
   - Display different content based on user role/verification

## Learnings
1. The app consistently uses daisyUI component classes over custom CSS
2. LiveView components follow a pattern of header + content sections
3. Access control is handled at multiple levels (router, LiveView, Ash policies)
4. The virtual_link field is sensitive and has a calculated visible version

## Next Steps
1. Create `/groups/:group_id/huddlz/:id` route and LiveView
2. Implement HuddlLive.Show module following GroupLive.Show patterns
3. Add event type badges/indicators
4. Implement RSVP functionality display
5. Handle virtual link visibility based on membership/RSVP status
6. Add navigation from list view to individual huddl pages