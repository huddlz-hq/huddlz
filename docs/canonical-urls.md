# Public canonical URLs

Public group pages use `/groups/:slug`; anonymously visible huddl pages use
`/groups/:group_slug/huddlz/:id`. Their canonical links and Open Graph URLs use
Phoenix's configured endpoint URL (`PHX_SCHEME`, `PHX_HOST`, and the configured
URL port), never the request host. Query parameters do not affect these detail
handlers, so their canonical URLs omit them. Group Upcoming/Past tabs are local
LiveView state, with no separate URL.

Discovery uses a self-referencing `/discover` URL retaining every query
parameter, including scope, search, location, date, sort, and pagination. This
conservative policy also retains unknown parameters rather than assuming they
are disposable. Different pages and filters are not collapsed onto unfiltered
results or page one. Existing out-of-range page handling remains in place.
This change does not introduce a noindex policy for search results.

Private groups, members-only huddlz, drafts, and cancelled huddlz do not receive
public canonical links, even when an authorized viewer can access them.
Authorization still controls anonymous HTTP responses. Canonical links are not
an access-control mechanism.

The initial HTTP document contains the canonical in its head. During LiveView
navigation, the live layout synchronizes the canonical and `og:url` with the
new view, removing absent values so previous-page URLs cannot linger.

There are no legacy HTML detail aliases or slug-history redirects in the
current router. An incorrect group slug does not resolve a huddl. Future slug
migrations and redirects belong with the actual URL migration, not speculative
routes. There is currently no sitemap; #258 should use the same verified detail
paths and endpoint configuration. Crawlable-link and structured-data work stay
in #260 and #162.

Deployment configuration is unchanged: runtime defaults are `https` and
`huddlz.com`, while the checked-in `fly.toml` sets `PHX_HOST=huddlz.fly.dev`.
Operators must configure the intended launch host; local verification does not
establish the deployed host or Google's selected canonical.

References:

- [Google canonical URL guidance](https://developers.google.com/search/docs/crawling-indexing/consolidate-duplicate-urls)
- [Google pagination guidance](https://developers.google.com/search/docs/specialty/ecommerce/pagination-and-incremental-page-loading)
