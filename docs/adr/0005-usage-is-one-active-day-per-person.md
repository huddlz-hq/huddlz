# Usage is recorded as one active day per person

The platform overview needs to say how many people use huddlz, not only how many have accounts, and retention charts later will need the history behind that figure. Nothing recorded it: the activity log only sees participation, and some of its entries are changes done to a person by someone else. We decided to record at most one fact per person per UTC calendar day, and nothing else about the visit.

A day is recorded when a signed-in person makes a browser page request, opens a page by live navigation, or calls the API or GraphQL with a bearer token or API key. An agent acting with a person's key is that person using huddlz. Socket heartbeats and reconnects, background jobs, email delivery and changes applied to a person by someone else or automatically record nothing. While an administrator views huddlz as someone, the administrator is recorded.

The rows hold a person and a date. They stay for as long as the account exists and are deleted with it. Measurement began when this shipped; earlier days are not backfilled and figures that would compare against unmeasured days say when measuring began instead.

The deployment migration records the UTC collection-start date separately from active days. Days with no usage are still measured, and deleting accounts must not move that date. The first date is partial: a previous period is comparable only when it starts after that date. Sparkline buckets can include the partial first date, while buckets ending before collection began stay unmeasured.

On each node, concurrent requests for the same person share a lock around recording and caching a successful write. Failed writes are not cached, so a later request can retry. The database upsert still protects against duplicate rows across nodes and restarts.

## Considered options

- **A last-active timestamp on the account.** Rejected: it answers "when was this person last here" but loses the history a distinct-people count over any past period needs.
- **Counting the activity log.** Rejected: browsing is absent from it, and an organizer removing someone would make that person look active.
- **Recording every request.** Rejected: click-level journeys are out of scope, and one fact a day is enough for every figure we plan to show.

## Consequences

Active people is a distinct count of people over dates, so a person using huddlz across midnight UTC counts on both dates and once in a period. Because the administrator's own visit counts, the overview never shows fewer than one active person to the administrator reading it. A future per-visitor or per-page measurement is a new decision, not an extension of this one.
