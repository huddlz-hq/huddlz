---
status: accepted
---

# Derive scheduling time zones from location and limit viewer choice to Calendar

Every group has a required physical Group location whose canonical IANA time zone becomes the Group time zone. Physical and hybrid huddlz derive their authoritative Huddl time zone from their selected physical location; virtual huddlz copy the Group time zone when created. Neither is an independent organizer preference, and later Group-location changes do not reschedule existing huddlz.

People do not choose an account or Profile time zone. Calendar time zone is the only viewer-controlled time-zone concept: Automatic resolution uses the browser, then the derived home Location time zone, then `America/New_York`; a person may choose a fixed Calendar zone from Calendar. Calendar time zone governs Calendar boundaries and presentation, while non-Calendar surfaces present each huddl in its authoritative Huddl time zone.

Resolved instants remain stored in UTC for ordering and comparison. Recurring schedules are generated from local wall-clock time plus the authoritative Huddl time zone so they retain their intended local time across daylight-saving changes. Nonexistent times advance by the DST gap, ambiguous times allow either occurrence, venue moves preserve the entered wall-clock time, and calendar exports carry named time-zone semantics. Existing missing values are backfilled deterministically with `America/New_York` rather than inferred from address text.
