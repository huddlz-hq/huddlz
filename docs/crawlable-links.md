# Crawlable public links

Audit baseline: `a13ef31f` on main (2026-09-07), including canonical URLs
(PR #431) and sitemaps (PR #433). This work addresses #260 independently of
structured data (#162).

## Findings

- Home already renders an ordinary `/discover` link for anonymous visitors.
- Discovery renders huddl cards as anchors to
  `/groups/:group_slug/huddlz/:id`. Its Groups link exposes the public group
  listing; group cards link to `/groups/:slug`. These agree with the existing
  canonical and sitemap detail paths.
- Discovery queries run during the initial HTTP request, before any socket
  connection. Its previous pagination controls were buttons without hrefs:
  pages after the first were inaccessible through those controls without
  JavaScript. Pagination now renders patch links with ordinary hrefs for
  previous, next and numbered pages, retaining active filters and group scope.
  First-page links omit `page=1`; disabled boundary controls have no href.
- Group detail pages render up to ten upcoming huddl links. Discovery provides
  the complete paginated path to upcoming and in-progress public huddlz, so this
  group preview does not need to become a second upcoming pagination system.
- Past/completed public detail pages are indexable and included in sitemaps.
  Previously the group Past tab and its pagination were socket-only state.
  They now expose `/groups/:slug?tab=past` and `&page=N` through ordinary
  links. Upcoming stays the default, and switching back omits archive params.
  Archive pages have distinct canonical and Open Graph URLs, while huddl
  detail URLs remain unchanged. Past huddlz sort newest first, with an ID
  tie-breaker for matching dates. Out-of-range pages redirect to the last page.
  The complete on-site archive path runs through public group discovery;
  no extra combinations of discovery filters need to be generated.
- A huddl detail page has no group backlink. This does not orphan either page:
  public groups have their own discovery listing, and huddlz have discovery
  links. No additional backlink is required to meet this issue.

## Intentional exclusions and crawl boundaries

Anonymous resource policies exclude private groups, members-only huddlz,
public-looking huddlz inside private groups, drafts and cancellations. Deleted
records cannot resolve. Anonymous detail requests return 404 for these records;
public listings do not link to them. Cancelled huddlz remain available only to
organizers and people with RSVP history, consistent with canonical and sitemap
eligibility. This change does not broaden those permissions.

Personal dashboards, calendars, notifications, profile pages, management routes,
and discovery `yours=hosting|attending` require authentication and are not public
indexable listing paths. Sign-in/registration links are navigation, not public
huddl content. There is no new robots/noindex policy in this change.

Existing filter links remain usable; pagination retains their search, format,
date, sort and location context. No arbitrary search terms, locations or new
filter combinations are generated to expand the crawl surface. A sitemap is an
additional discovery mechanism; the archive is also reachable entirely through
on-site anchors, starting at home.

## Verification

The Cucumber scenario starts with anonymous home HTML, follows the actual
Browse href, follows pagination hrefs, and requests every linked huddl detail
with 21 public fixtures. A second scenario follows group discovery and the Past
link through multiple archive pages and published/completed detail pages.
Additional HTTP tests cover paginated group listings,
past-filter pagination, filter context, invalid archive parameters and exclusion of restricted/deleted
records. These checks use initial responses, not a DOM after JavaScript runs.

An isolated local browser server with 21 upcoming huddlz verifies next-page
navigation, detail navigation and browser Back retaining page two. Archive
browser checks cover Past, next/previous, direct reload and returning to Upcoming. Local tests
prove response contents and navigation, not search-engine indexing. Production
host configuration, deployment and search-engine acceptance remain rollout
checks; no deployment or Search Console operation is included here.

References:

- [Google crawlable link guidance](https://developers.google.com/search/docs/crawling-indexing/links-crawlable)
- [Canonical URL policy](canonical-urls.md)
- [Sitemap visibility contract](sitemaps.md)
