# Public sitemaps

`/sitemap.xml` is a sitemap index. Its children are root-level
`/sitemap-<sha256>.xml` documents. `robots.txt` advertises the index using the
configured endpoint origin, also used by canonical and Open Graph URLs.

## Generation and scale

The existing Oban scheduler refreshes at boot and every 15 minutes. It writes
XML into PostgreSQL, shared by all Fly machines and preserved across restarts.
Crawler requests read one stored document by primary key; they never scan the
communities tables or trigger generation. Responses use `application/xml`,
ETags and a five-minute public cache lifetime. Before the first successful
refresh, the index returns 503 with `Retry-After: 900` and `no-store`. A
successfully generated empty public catalog returns `204 No Content`: the
authoritative XML schema requires at least one child, so an empty XML index
would be invalid. The next scheduled refresh discovers newly published pages.

Generation streams one SQL cursor in batches of 500 rows, selecting only kind,
ID, group slug and modification time. Its explicit public predicates match
anonymous page access: public groups, and non-private published/completed
huddlz inside public groups. No full Ash resources, relationships, or attendee
lists are loaded. The cursor's single statement gives a consistent MVCC
snapshot, with unique `(kind, id)` ordering and no shifting pagination offsets.
Concurrent mutations enter the next refresh. The database may sort/spill the
projected rows; application memory holds one child document and a bounded index.

Children default to 5,000 URLs, keeping per-document memory and responses small.
Both the serializer and index enforce the protocol ceilings of 50,000 entries
and 52,428,800 uncompressed bytes, including XML envelopes. Oversized entries
or indexes fail generation rather than publishing a partial feed. If the index
ever approaches its own ceiling, a separate multi-index rollout is required.

A transaction-scoped PostgreSQL advisory lock allows only one generator across
machines. Child writes and index replacement commit together. A failed refresh
rolls back and leaves the last published generation available; Oban retries up
to three attempts, and subsequent scheduled runs retry again. A competing job
that finds the lock held exits without scanning. Content-derived filenames stay
unchanged for unchanged XML. Previous child files remain for at least 48 hours
**after supersession**, including when generation resumes after a long outage.
Successful refreshes collect expired historical children. This window exceeds
the index's five-minute HTTP cache lifetime; indefinitely saved old indexes
are not guaranteed to resolve forever.

## Freshness, privacy and modification times

Publishes, edits, slug changes, privacy changes, cancellations and deletions
enter the next successful scheduled snapshot. There is no per-write generation
or invalidation fan-out. In healthy operation, discovery freshness is up to
15 minutes plus generation time and up to five minutes of HTTP caching. An
outage can extend it: monitor the refresh worker's failures and the active
index row's `retained_at` timestamp. Historical children may still mention
formerly public URLs until their retention expires. Sitemap removal is not an
access-control mechanism: ordinary anonymous page reads enforce current
visibility and return 404 for inaccessible/deleted pages immediately.

Past and completed public huddlz stay listed because their detail pages remain
public and canonical. Cancelled huddlz are excluded: current access rules make
them visible only to organizers and people with RSVP history. Drafts and
private content are excluded. Administrative deletion and group deletion are
also reflected in the next snapshot. This task does not broaden page access.

`lastmod` is a content timestamp, never generation time. A database-maintained
huddl `sitemap_modified_at` records actual attribute changes while excluding
`updated_at`, reminder stamps and its own bookkeeping. It covers ordinary Ash
updates, recurring bulk edits and lifecycle actions. Migration backfill uses
the best available historical `updated_at`; it cannot reconstruct older
reminder-only history. Group detail edits use their ordinary `updated_at`.
Artwork triggers retain modification time on the parent for image assignment,
replacement and removal, including hard deletion; cleanup of an already
soft-deleted image does not advance it again. huddl entries also include group modification times, since group metadata
and artwork affect rendered detail content. Address-book reference changes do
not advance the timestamp: the public page renders its copied address. Live attendance counts are not treated as editorial modifications.
The sitemap timestamp columns are database-maintained metadata, intentionally
not exposed as writable Ash attributes.

## Rollout and verification

Apply the migrations before starting the new release. They add stored documents,
content timestamps and triggers, and backfill existing rows. Confirm the endpoint
scheme/host points at the intended production canonical origin. After the boot
job completes, fetch `/robots.txt`, the index, and every referenced child; check
XML parsing, HTTP status/content type and representative anonymous linked pages.
An operator can enqueue an immediate refresh through the existing release:

```elixir
%{} |> Huddlz.Sitemaps.Refresh.new() |> Oban.insert()
```

Observe refresh duration/failures and storage growth at production scale. Local
tests exercise actual protocol boundaries using streams and multi-batch database
generation without thousands of ancillary fixtures. They do not establish
production database performance or Google acceptance. Production verification
and Search Console submission are rollout steps requiring separate authorization.
No deployment or Search Console submission is part of this change.

References: [Sitemap protocol](https://www.sitemaps.org/protocol.html) and
[Google's sitemap guidance](https://developers.google.com/search/docs/crawling-indexing/sitemaps/build-sitemap).
