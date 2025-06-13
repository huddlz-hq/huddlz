# Issue #53: Unable to see past events

## Issue Details
- **URL**: https://github.com/huddlz-hq/huddlz/issues/53
- **Reporter**: MichaelDimmitt
- **Created**: June 12, 2025

## Problem Statement
Users are unable to view past events on the home page. The issue affects the visibility of historical huddlz (events), preventing users from accessing completed or past scheduled events.

## Root Cause Analysis
After analyzing the codebase:
1. The Huddl resource has an `:upcoming` action that filters for future events only (`starts_at > DateTime.utc_now()`)
2. The `:by_group` action also filters out past events
3. There is no read action to retrieve past events
4. The home page is currently empty and doesn't display any huddlz

## Solution
Implement a new `:past` read action that filters huddlz where `starts_at < DateTime.utc_now()` and update the UI to display these past events.

## Task Breakdown

### Task 1: Add :past read action to Huddl resource
- Add new read action in the actions block
- Filter for `starts_at < DateTime.utc_now()`
- Apply visibility preparation
- Sort by starts_at descending (newest past events first)

### Task 2: Add authorization policies
- Mirror the `:upcoming` action policies
- Allow public huddls in public groups
- Allow any huddl in groups user is member of

### Task 3: Write feature tests
- Create Cucumber feature for viewing past huddlz
- Test past events are returned correctly
- Test future events are excluded
- Test authorization works properly

### Task 4: Update UI to display huddlz
- Implement huddl display on HomeLive
- Add sections for upcoming and past events
- Use the new `:past` action to fetch data
- Consider pagination for large result sets

### Task 5: Quality assurance
- Run all tests
- Format code with `mix format`
- Run `mix credo --strict`
- Verify in browser that past events display correctly

## Success Criteria
- [x] Past events can be retrieved via the `:past` action
- [x] Authorization policies are properly configured
- [x] Feature tests pass
- [x] UI displays both upcoming and past huddlz
- [x] All quality checks pass

## Feature Branch
`feature/issue-53-view-past-events`