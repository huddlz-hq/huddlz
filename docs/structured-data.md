# Public structured data

Issue: [#162](https://github.com/huddlz-hq/huddlz/issues/162). Audit date: 2026-09-07.

## Verified gap

Main at `a13ef31f` had no JSON-LD implementation. Anonymous production HTTP
responses for [Jax.Ex](https://huddlz.com/groups/jax-ex) and its
[public huddl](https://huddlz.com/groups/jax-ex/huddlz/1bff1410-6d4e-45f9-90fc-55b66063961e)
contained visible titles, descriptions, canonical links and Open Graph metadata,
but zero `application/ld+json` blocks. The canonical and sitemap work was already
merged in #431 and #433. This change uses those existing detail-page URLs.

## Mapping and privacy

Public huddl detail pages emit one schema.org `Event` object. Dates use the
huddl's time zone and the applicable UTC offset. Each generated recurring
occurrence uses its own detail URL and dates. Images follow the same uploaded
artwork and group fallback as the visible page; missing artwork is omitted.
The organizing group supplies the organizer name and public URL.

Physical locations use the publicly displayed address as `PostalAddress.name`,
without guessing address components or publishing an address-book name that the
page does not show. Virtual locations identify the visible online attendance
option; they never contain the restricted join URL, including when the viewer
is an organizer or attendee. Hybrid huddlz include both location types.
[Google's address examples](https://developers.google.com/search/docs/appearance/structured-data/event#structured-data-type-definitions)
and [schema.org VirtualLocation](https://schema.org/VirtualLocation) support these
vocabularies; their presence alone does not establish rich-result eligibility.

Public group pages emit `Organization` with the group's visible name,
description, home location and available artwork. A home city is not asserted
to be a headquarters or mailing address, and a cover image is not called a logo.
Private membership details and owner contact information are excluded.
[Google's Organization guidance](https://developers.google.com/search/docs/appearance/structured-data/organization)
has no required properties and recommends supplying relevant, available facts.

## Lifecycle limits

The existing public canonical URL gate permits only published/completed public
huddlz in public groups. Drafts, private pages and cancelled huddlz omit JSON-LD
even for authorized viewers; anonymous requests remain 404. Publishing cancelled
metadata would require a separate decision to change that visibility policy.

Schedule edits replace the current dates. There is no persisted prior start date
or public rescheduled state, so the markup does not invent `previousStartDate`
or `EventRescheduled`. `EventScheduled` also covers a huddl that has already
taken place as scheduled. See [schema.org's status definition](https://schema.org/EventScheduled).
Consequently, #162's original cancellation/rescheduling acceptance wording is
not fully implemented; these are deliberate limits of the current domain model.

## Rendering and verification

The shared component renders inert JSON-LD inside the LiveView body. It is in
the initial response and is replaced with the view during navigation, without
adding head synchronization code. JSON serialization escapes HTML delimiters
before marking the encoded string safe. The [HTML standard](https://html.spec.whatwg.org/multipage/scripting.html#the-script-element)
distinguishes data blocks from executable JavaScript; the template contains no
executable inline script. Google accepts JSON-LD in the
[head or body](https://developers.google.com/search/docs/appearance/structured-data/intro-structured-data).

HTTP acceptance scenarios and integration checks parse JSON and cover attendance
modes, date offsets, recurrence identities, current schedule updates, artwork,
host/query-independent URLs, hostile strings, and privacy exclusions. Connected
LiveView checks cover updated dates and navigation. Synthetic fixtures on a
dedicated local server were checked in a real browser, including group-to-huddl
navigation and private-link absence. A separate HTTP fetch and JSON parser
verified the initial hybrid HTML, independent of the browser DOM.

## Rollout limitations

Production Rich Results Test and Search Console checks were not performed.
No private data was submitted to an external validator. After deployment, test
representative public physical/hybrid URLs and verify artwork accessibility and
quality. Purely virtual huddlz are outside Google's current specialized
experience, and membership/invitation requirements can also make a gathering
ineligible. Structured data cannot guarantee indexing or enhanced presentation.
See [Google's eligibility guidance](https://developers.google.com/search/docs/appearance/structured-data/event#guidelines).
