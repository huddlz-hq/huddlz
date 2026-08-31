# Calendar time zones, DST transitions, and iCalendar

## Question

How should huddlz handle local scheduling times that are nonexistent or ambiguous because of daylight-saving transitions, and what must a timezone-aware `.ics` export contain?

## Findings

### Spring-forward gaps

A local wall-clock time inside a spring-forward gap does not identify a valid instant. RFC 5545 resolves such a value using the UTC offset before the gap; its New York example therefore resolves `2:30 AM` to `3:30 AM EDT`. Java's `ZonedDateTime` follows the same general policy by shifting the value forward by the length of the gap. [RFC 5545 §3.3.5](https://www.rfc-editor.org/rfc/rfc5545.html#section-3.3.5), [Java `ZonedDateTime`](https://docs.oracle.com/en/java/javase/26/docs/api/java.base/java/time/ZonedDateTime.html)

### Fall-back overlaps

A local wall-clock time inside a fall-back overlap identifies two valid instants. RFC 5545 chooses the first occurrence, which is the earlier instant and normally the daylight-time offset. Java likewise defaults to the earlier offset, while still providing APIs to select the later one. Apple Foundation's repeated-time policy also defaults to the first occurrence. [RFC 5545 §3.3.5](https://www.rfc-editor.org/rfc/rfc5545.html#section-3.3.5), [Java `ZonedDateTime`](https://docs.oracle.com/en/java/javase/26/docs/api/java.base/java/time/ZonedDateTime.html), [Apple `Calendar.nextDate`](https://developer.apple.com/documentation/foundation/calendar/nextdate%28after%3Amatching%3Amatchingpolicy%3Arepeatedtimepolicy%3Adirection%3A%29)

Elixir does not force either resolution on the application. `DateTime.from_naive/3` returns the two boundaries of a gap or the two possible datetimes of an overlap. Its documentation specifically says time-sensitive applications must account for these cases and communicate them to users. This is the appropriate seam for huddlz to apply its scheduling policy. [Elixir `DateTime`](https://hexdocs.pm/elixir/DateTime.html#from_naive/3)

## Recommended huddlz behavior

- Treat the organizer's wall-clock date and time plus the huddl's authoritative IANA time zone as the scheduling intent.
- For a nonexistent spring-forward time, resolve forward by the gap, consistent with RFC 5545 and common runtime behavior, but show the adjusted local time and abbreviation before saving. Do not silently change the organizer's entry.
- For an ambiguous fall-back time, default to the first occurrence, consistent with RFC 5545, Java, and Apple. Show the abbreviation or UTC offset in the confirmation and offer the second occurrence as an explicit alternative.
- Generate recurring occurrences from local wall-clock time in the huddl time zone, then store each resolved instant in UTC. Do not generate a wall-clock recurrence by repeatedly adding fixed 24-hour UTC durations. Elixir warns that fixed elapsed-time addition can shift a recurring meeting's local hour across DST, while Google requires an IANA time zone to expand recurrence. [Elixir `DateTime.add/4`](https://hexdocs.pm/elixir/DateTime.html#add/4), [Google Calendar API time zones](https://developers.google.com/workspace/calendar/api/concepts/events-calendars#time_zones)

## Correct timezone-aware `.ics` output

An `.ics` file can represent a one-off huddl correctly using UTC `DTSTART` and `DTEND` values ending in `Z`; this identifies the exact instants even without a named time zone. It does not, however, preserve the huddl's authoritative local-time context.

To preserve that context, and especially to preserve local wall-clock intent for recurrence:

- Emit local `DTSTART` and `DTEND` values with a `TZID` parameter, for example `DTSTART;TZID=America/New_York:20261103T090000`.
- Include one matching `VTIMEZONE` component in `VCALENDAR` for every referenced `TZID`. Its observances must cover every generated recurrence instance. RFC 5545 warns that omitting the definition can cause inconsistent interpretation. [RFC 5545 §3.2.19](https://www.rfc-editor.org/rfc/rfc5545.html#section-3.2.19), [RFC 5545 §3.6.5](https://www.rfc-editor.org/rfc/rfc5545.html#section-3.6.5)
- Include the normal calendar envelope and entry identity fields: `PRODID` and `VERSION` on `VCALENDAR`; `UID`, `DTSTAMP`, and `DTSTART` on `VEVENT`; and either `DTEND` or `DURATION` when an explicit duration is needed. Add `RRULE` for a recurring huddl. [RFC 5545 §3.6](https://www.rfc-editor.org/rfc/rfc5545.html#section-3.6), [RFC 5545 §3.6.1](https://www.rfc-editor.org/rfc/rfc5545.html#section-3.6.1)
- Never export a scheduled huddl as a floating local time without `TZID`; RFC 5545 defines that as following the recipient's current time zone, so different attendees may receive different instants. [RFC 5545 §3.3.5](https://www.rfc-editor.org/rfc/rfc5545.html#section-3.3.5)

## Decision implication

Timezone-aware `.ics` generation belongs in the timezone correction scope. Every huddl should have an authoritative IANA time zone. Exports should use that zone through `TZID` plus `VTIMEZONE`; UTC-only output remains technically correct for a one-off huddl but should not be the product's canonical representation.
