# LiveView head metadata research

Research date: 2026-09-07. Scope: alternatives to the URL metadata JavaScript hook in PR #431 / issue #259. No production code changed or dependency installed for this research.

## Existing community solution

`phoenix_live_head` is an existing library specifically for updating the HTML head from Phoenix LiveView. Its README describes head commands, including attribute and CSS-class manipulation, and explicitly requires importing its client JavaScript into `assets/js/app.js`. Thus it provides a reusable API, but does not eliminate JavaScript from live head updates. The maintainer describes the project as operational despite infrequent updates. [Repository and installation instructions](https://github.com/BartOtten/phoenix_live_head).

Hex currently lists release 1.0.0, last updated September 24, 2025. That establishes an existing published option; it does not prove compatibility with huddlz's installed LiveView 1.2.11. This research did not install or exercise the package. The public source defines `Phx.Live.Head` commands accepting a LiveView socket and imports `Phoenix.LiveView.push_event/3`; the browser selects elements using CSS selectors. Package compatibility and current CI coverage were not verified. [Elixir implementation](https://github.com/BartOtten/phoenix_live_head/blob/main/lib/live_head.ex). [Hex package](https://hex.pm/packages/phoenix_live_head).

## Native portals

LiveView has a native `Phoenix.Component.portal/1` API. The documentation describes moving component content to another DOM location and explicitly notes that it uses HTML `template` elements. [Component documentation](https://phoenix-live-view.hexdocs.pm/Phoenix.Component.html#portal/1).

The installed source at `deps/phoenix_live_view/lib/phoenix_component.ex:3601` renders a `template` with a `data-phx-portal` target and an enclosing element that defaults to `div`. Its comment identifies LiveView JavaScript as responsible for teleporting the element. Consequently, rendering a portal in the body does not itself put a canonical link into the initial response's head. A portal-based replacement would need separate initial head rendering and a carefully tested ownership/deduplication strategy after connection; simply adding `target="head"` would not preserve the PR's initial-HTML guarantee. This is an inference from the installed implementation, not a verified replacement design.

## Initial HTML versus navigation

There is an established maintainer discussion of this exact canonical/metadata problem. José Valim and Chris McCord recommend providing metadata in the initial HTTP response and distinguish crawler fetching from a human's live navigation. Their advice supports evaluating whether browser-DOM synchronization is necessary at all for this launch ticket. [Maintainer discussion](https://elixirforum.com/t/updating-metatags-in-phoenix-liveview-rel-canonical-etc/36715).

Google's documentation separately supports rendering canonical metadata in original HTML and describes discovering URLs from links and fetching/rendering URLs. Its warning against changing an original canonical should not be stretched into an unverified claim that user-triggered SPA navigation is forbidden. [Google JavaScript SEO guidance](https://developers.google.com/search/docs/crawling-indexing/javascript/javascript-seo-basics).

## Recommendation for #259

Prefer the existing server-rendered canonical and `og:url` values in the root layout, with HTTP-level tests for every public route/query variant, for the launch SEO requirement. Removing browser-DOM synchronization is a coherent simplification if metadata after human live navigation is not itself a product requirement. It preserves live navigation and needs neither an extra package nor custom head JavaScript. This recommendation concerns the implementation scope, not proof of production indexing.

If keeping the browser head synchronized is an explicit requirement, the current small hook and `phoenix_live_head` are alternatives worth comparing. Replacing two targeted tag updates with a broader package requires an actual compatibility and navigation test first; the library's existence alone does not establish that it is a better fit. Native portals are not a drop-in substitute for correctly populated initial response metadata.
