# Issue #34: User Profiles

## Overview
Fix display name persistence bug and add user profile management functionality.

## Problem Statement
- **BUG**: Users get a new random display name every time they log in
- **MISSING FEATURE**: Users cannot update their display name after registration

## Requirements

### 1. Display Name Bug Fix
- Only generate display name on initial user creation
- Keep existing "ColorAnimal123" format
- Existing users keep their current names

### 2. Profile Management
- Add profile icon (generic person SVG) to navbar
- Create dropdown menu with: Profile, Admin Panel (conditional), Theme toggle, Sign Out
- Create `/profile` page for display name management
- Move Groups link to left side of navbar

### 3. Design Decisions
- Theme toggle becomes a logged-in user perk
- Simple form-based profile page
- Display name validation: 1-30 characters
- Flash message for success feedback
- Mobile: hamburger (left) → brand → profile icon (right)

## Task Breakdown

### Task 1: Fix display name bug + regression test ⏳
Fix the root cause and ensure it doesn't regress.

### Task 2: Add profile icon and dropdown structure ⏳
Basic navbar restructuring and dropdown component.

### Task 3: Populate dropdown menu and move items ⏳
Complete the dropdown functionality and reorganize navbar items.

### Task 4: Create basic profile LiveView ⏳
Set up the `/profile` route and page structure.

### Task 5: Implement profile update functionality ⏳
Complete the display name update feature.

## Testing Strategy
- Regression test for display name persistence
- Feature tests for profile management
- Manual testing of dropdown on mobile/desktop

## Status: Planning Complete ✅
Ready to begin implementation with `/build issue=34`