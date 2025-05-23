# Feature: Event Creation (Huddlz)

## Overview
Enable group owners and organizers to create huddlz (events) for their groups. This is the most fundamental feature of the platform - without huddlz, there's no way for people to know when or where to meet. This MVP implementation focuses on one-time event creation with basic RSVP tracking.

## User Stories
- As a group owner, I want to create huddlz for my group, so that members know when and where to meet
- As a group organizer, I want to create huddlz for groups I help manage, so that I can schedule meetups
- As a group member, I want to see upcoming huddlz for my groups, so that I can plan to attend
- As a user, I want to RSVP to huddlz, so that organizers know I'm coming
- As a user, I want to search and browse public huddlz, so that I can discover interesting events

## Implementation Sequence
1. Update Huddl Resource - Add new fields and relationships for events
2. Create Event Form - Build LiveView form for event creation
3. Implement Access Control - Ensure only owners/organizers can create events
4. Add Event Display - Show events on group pages and main listing
5. Implement RSVP System - Basic RSVP functionality with count display
6. Add Event Search - Enable searching/filtering of public events

## Success Criteria
- Group owners and organizers can create one-time events
- Events can be in-person, virtual, or hybrid
- Virtual links are only visible to attendees
- Private groups create private events only
- Public groups can create public or private events
- Users can RSVP to events they have access to
- RSVP count is displayed (not individual attendees)
- Events appear on group pages and main search page
- Past events cannot be created
- Event end time must be after start time

## Planning Session Info
- Created: January 23, 2025
- Feature Description: Event creation functionality for groups