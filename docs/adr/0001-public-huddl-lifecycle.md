# Public cancellation and schedule history

Cancelled public huddlz retain their anonymous detail page and canonical URL while their group remains public. Preserve the last scheduled dates and publish `EventCancelled`, but keep cancellation reasons restricted to organizers and people with RSVP history. Private huddlz and private groups retain their access restrictions. Cancelled huddlz stay out of discovery and remain sitemap-eligible only until their scheduled end time.

A change to a published huddl's start instant counts as rescheduling. Keep the immediately previous start instant and its time zone, show that previous start alongside the current schedule, and publish `EventRescheduled` with `previousStartDate`. Draft edits and end-time-only edits do not create history. Subsequent rescheduling replaces the previous start; existing history is not backfilled. Cancellation takes precedence over rescheduling metadata and preserves the schedule in effect at cancellation.
