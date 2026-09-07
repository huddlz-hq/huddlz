# Browser testing assessment

Research date: 2026-09-07. Repository baseline: `a13ef31faddba3fc6efb142accfbe2b08a910479`.
Scope: [#420](https://github.com/huddlz-hq/huddlz/issues/420), including requirements
consolidated from [#372](https://github.com/huddlz-hq/huddlz/issues/372).
This is an exploration recommendation, not implementation or proof of browser CI performance.
No browser framework was installed, scenario converted, or CI job added.

## Recommendation and launch priority

Retain the existing fast suite and manual browser verification for now. There is
credible incremental value in a tiny native-keyboard smoke test, but insufficient
runtime, reliability, and ownership evidence to adopt infrastructure. If separately
authorized, evaluate PhoenixTest.Playwright first, bounded to the organizer controls
below; consider one cover-layout check only after the first case proves its value.
Do not migrate the suite.

The coverage gap is real, but browser automation is not established as a launch
blocker. #420 has no priority label and explicitly leaves adoption undecided;
#297 and #305 are closed. Their acceptance criteria establish important product
behavior, not a requirement to automate a browser before launch. Open
[#304](https://github.com/huddlz-hq/huddlz/issues/304) concerns actual focus behavior;
fixing and manually verifying that behavior has more direct launch value than
building a general test platform. This priority is an assessment, not an agreed
product decision. Reconsider if native regressions recur or manual checks are
regularly omitted.

## What the current suite proves, and misses

[Testing guidance](../testing.md) makes Cucumber the outer behavior specification,
with PhoenixTest for web behavior and public application boundaries for other rules.
[Current setup](../../test/test_helper.exs) compiles features into ExUnit;
[hooks](../../test/features/support/hooks.exs) establish sandbox and Plug connections.
The lockfile pins PhoenixTest 0.12.1, Cucumber 1.0.0, and LiveView 1.2.11.
The following are regression classes grounded in named issues, not claims that
these fixed bugs were reproduced during this exploration.

| Evidence | Existing protection | Distinct browser assertion |
| --- | --- | --- |
| [#297 organizer controls](https://github.com/huddlz-hq/huddlz/issues/297) | [Create tests](../../test/huddlz_web/live/huddl_live/new_test.exs), [edit tests](../../test/huddlz_web/live/huddl_live/edit_test.exs), and [group tests](../../test/huddlz_web/live/group_live_test.exs) assert native input types, labels, checked/ARIA state and equivalent form changes. | Tab reaches visually hidden inputs; Space changes a switch; arrow keys change the radio selection; the card has a visible focus outline; checked and ARIA state survive a real LiveView patch. Removing focus CSS or hiding an input with `display:none` could break this while those HTML assertions still pass. |
| [#305](https://github.com/huddlz-hq/huddlz/issues/305), fixed by [#353](https://github.com/huddlz-hq/huddlz/pull/353) | [Cover component tests](../../test/huddlz_web/components/cover_image_test.exs) prove URL escaping/markup; [group detail tests](../../test/huddlz_web/live/group_live/show_test.exs) prove fallback and cover elements exist. | At 320 CSS px, long names/locations do not overflow or cover actions; a failed cover request leaves a visible fallback. These require actual CSS layout and painting. |
| [#303 mobile drawer](https://github.com/huddlz-hq/huddlz/issues/303) | [Six Node tests](../../assets/js/mobile_navigation_test.mjs) already check state, focus calls, Escape and Tab wrapping against fake elements. | Actual `inert`, native tab traversal, breakpoint CSS and focus restoration after live navigation. This is reserve scope, not a third initial test. |

Similarly, [autocomplete steps](../../test/features/step_definitions/location_autocomplete_steps.exs)
call `render_keydown`; they prove the server response to a supplied key payload,
not browser key dispatch. Conversely, permission rules, RSVP/capacity, recurrence,
notifications, API contracts, validation text, and accessible markup already have
appropriate fast seams. Browser execution would mostly duplicate that coverage.

[#373](https://github.com/huddlz-hq/huddlz/issues/373) reports a MutationObserver
error seen during browser validation, with no observed lifecycle failure. Its call
site and application ownership remain unknown. It supports collecting diagnostics,
not a blanket console-error assertion or a claim that automation would have caught
a confirmed application regression. No existing browser session was disturbed or
new native-behavior investigation performed for this report.

## Measured baseline

One sample per command; no distributions or clean cold-build benchmark. Local
macOS 26.6.2, ARM Mac17,6, 18 logical CPUs, 128 GiB RAM, Elixir 1.20.2 / OTP 29
(ERTS 17.0.3), PostgreSQL 17.10. Dependencies and `_build` were hydrated by the
worktree hook; the application recompiled 278 files. Dedicated database
`huddlz_research_420_20d8`, port 4420, and worktree-local files isolated test data.
The shared database server and host still share resources with other work.

| Measurement | Result | Interpretation |
| --- | --- | --- |
| `/usr/bin/time -p mix precommit` | 40.31 s wall; ExUnit 25.8 s (17.4 async / 8.4 sync); 1,789 passed including one doctest; Credo passed | Includes compile, format, dependency cleanup, database setup, tests and lint. Seed 334757, max cases 36, inherited pool size 50. Setup briefly logged PostgreSQL too-many-connections errors; validation ultimately exited 0. Contention-affected, not an uncontended speed claim. |
| `/usr/bin/time -p mix test test/huddlz_web/live/huddl_live/new_test.exs:189` | 5.18 s wall; ExUnit 0.6 s; one passed, 288 excluded | Warm targeted “Members only” form-state test. Startup/feature compilation remains in wall time; not equivalent to native keyboard coverage. |
| `/usr/bin/time -p npm test --prefix assets` | 0.48 s wall; Node runner 59.46 ms; six passed | Node 26.8.1 locally; fake DOM tests, no browser. |
| Existing main CI `mix test` | 88 s step; ExUnit 82.2 s (67.7 async / 14.5 sync); same 1,789 passed | Seed 520881, max cases 8, configured pool 10. Ubuntu hosted runner, OTP 29.0.3 / Elixir 1.20.2, PostGIS 17-3.5, Node 22. |
| Existing main CI test job | 158 s elapsed; database initialization 24 s; compile 16 s | Restored dependency and compiled-build caches; still paid fresh job/container startup. Concurrent seed job took 73 s. Queue latency excluded. |

CI evidence: [run 34085675283](https://github.com/huddlz-hq/huddlz/actions/runs/34085675283)
at the baseline commit, retrieved with `gh run view 34085675283 --log` and
`gh api repos/huddlz-hq/huddlz/actions/runs/34085675283/jobs` (step durations from
completed minus started timestamps, rounded to seconds). The
[workflow](../../.github/workflows/elixir.yml) runs Node tests separately from Mix;
`mix precommit` itself does not include them or an asset build. Local command
output was captured in `/private/tmp/huddlz-420-{precommit,control,js}.log`; these
are temporary evidence, not committed artifacts. Host load averages before running
were 6.93/5.60/3.81. Pool size was reduced to 10 afterward for future worktree runs.
Existing missing-form-id and sandbox-owner-exit diagnostics also appeared; passing
checks are not a claim of clean logs. Neither “the suite takes seconds everywhere”
nor “browser tests will take hours” follows from these samples.

## Options with concrete decision value

| Approach | Fit and benefit | Cost / recommendation |
| --- | --- | --- |
| Keep manual verification | No new runtime/dependencies; humans inspect focus and rendering. | Recommended now. Assign a release reviewer and record browser/version, viewport, commit and results. Human time and omissions remain costs; not measured here. |
| Separate PhoenixTest.Playwright smoke | Elixir/ExUnit; familiar actions; native input, screenshots and traces. | First candidate for a later evaluation. Requires Hex adapter, Node Playwright, matching browser, serving endpoint/assets and new fixture integration. Similar API is not drop-in compatibility. |
| Separate Wallaby smoke | Elixir/ExUnit and concurrent browser sessions. | Credible fallback if required assertions or adapter compatibility fail. Chrome/ChromeDriver or Selenium driver setup and a different query DSL; screenshots and JS logs, with no equivalent trace viewer established by reviewed docs. |
| Playwright Test JS/TS | First-party runner and diagnostics. | Extra runner plus Elixir fixture/auth/sandbox bridge for two cases; consider only if Elixir options cannot meet needs. |
| Selective CI for a smoke suite | Repeatable native checks on relevant changes without delaying every PR. | Later stage only, after local qualification. Separate optional job first; explicit dispatch plus relevant-path selection, manual override, and release execution to catch filter omissions. |

Primary sources checked on the research date: [PhoenixTest.Playwright setup](https://phoenix-test-playwright.hexdocs.pm/readme.html),
[browser/session API](https://phoenix-test-playwright.hexdocs.pm/PhoenixTest.Playwright.html),
[configuration](https://phoenix-test-playwright.hexdocs.pm/PhoenixTest.Playwright.Config.html),
[Wallaby setup](https://github.com/elixir-wallaby/wallaby),
[Wallaby configuration](https://wallaby.hexdocs.pm/Wallaby.html), and
[Playwright Test](https://playwright.dev/docs/intro).
Opened adapter docs identify 0.16.0 and Wallaby docs 0.31.0; compatibility with
this lockfile was not exercised. Pin and verify exact versions in any authorized
follow-up rather than copying rolling documentation examples unchanged.

## Integration work that a future evaluation must prove

- **Authentication and data:** use a generated organizer and minimal owned group,
  with deterministic local covers and Places/Geocoding stubs. The current
  [login helper](../../test/support/helpers/authentication.ex) inserts Ash JWT
  `user_token` and `live_socket_id` into a Plug session. A browser needs a signed
  cookie with those values and matching endpoint options, or real login.
  The adapter provides `add_session_cookie`; prove an authenticated visit before
  keyboard testing. Cookie setup does not test the login UI itself.
- **Sandbox and LiveView:** HTTP and websocket processes must share the test's
  transaction before authentication queries. The existing
  [AllowEctoSandbox hook](../../lib/huddlz_web/hooks/allow_ecto_sandbox.ex) is unused;
  [endpoint](../../lib/huddlz_web/endpoint.ex) has neither sandbox middleware nor
  `user_agent` connect info. The test flag alone enables no browser plumbing.
  Use test-only middleware/metadata and Ash `on_mount_prepend`; close browser
  contexts before releasing ownership. See [Phoenix sandbox instructions](https://phoenix-ecto.hexdocs.pm/Phoenix.Ecto.SQL.Sandbox.html)
  and [Ash hook ordering](https://ash-authentication-phoenix.hexdocs.pm/AshAuthentication.Phoenix.LiveSession.html#ash_authentication_live_session/3).
- **Isolation and concurrency:** [ConnCase](../../test/support/conn_case.ex) Mox
  stubs need explicit allowance for HTTP/LiveView processes too. Rollback does
  not clean image files; use unique paths and cleanup. Start with one browser,
  serial cases, a dedicated database and unique port; do not reduce the fast
  suite's existing concurrency. Validate two isolated browser sessions only
  if later parallelism is justified. The adapter's default pool scales with
  schedulers, so configure it explicitly. External JS needs an additional
  fixture/sandbox bridge; do not expose a test endpoint in production.
- **Readiness and assets:** compile CSS/JS and serve actual assets; current CI
  does not build them. Wait for LiveView connection and an observable result
  after each interaction, not sleeps or network-idle on a persistent socket.
  Test-only stubs must not call Google, mail providers, or production storage.
- **Cucumber routing:** retain outside-in scenarios and fast domain seams.
  Cucumber supports [ExUnit tag filtering](https://cucumber.hexdocs.pm/Cucumber.html).
  A future `@browser` tag could select a dedicated browser context/step module;
  existing steps access Plug connections or `.view` and cannot simply be rerouted.
  Prefer a separate opt-in feature path and helper that are not compiled/started
  by ordinary `mix test`, with a proposed `mix test.browser` command. That command
  does not exist today. Do not install/start a browser just to exclude its tests.

## Smallest scope, budgets and exit decision

First candidate: one organizer choice-control scenario on a huddl create form.
Tab from the preceding field into the labeled format group; use radio arrow keys,
then Tab and Space on Recurring huddl and Members only. Assert active element,
visible card/switch focus, checked/ARIA synchronization and a resulting LiveView
form change. Cover create/edit and group visibility manually initially; expand
only for distinct behavior. Before qualification, demonstrate that this case
fails for a known keyboard/focus regression while the equivalent fast assertion
passes. This would establish incremental value; it has not been demonstrated here.

Only then consider a second group-detail case with deterministic long content,
valid/absent/failed CSS-background covers at 320 px and one desktop width.
Use overflow/bounding-box and interaction assertions, plus a focused screenshot
for diagnosis. A DOM element or successful URL alone does not prove a painted
fallback; retain human screenshot review unless a stable narrow visual oracle is
proven. Avoid whole-page pixel baselines and browser/viewport Cartesian products.
Accessibility state checks also do not replace manual screen-reader verification.

All numbers below are **proposed acceptance budgets, not measured forecasts**:

- Maximum two cases, one Chromium worker, zero automatic retries. Whole warm
  smoke command p95 at most 30 s, including app/browser startup and teardown;
  ordinary `mix test` has zero browser startup and no added browser execution.
- A later CI experiment must report warm test execution, cache-restored total job,
  and genuinely cold total job separately, including browser/OS installation,
  assets, database, fixture setup and artifact upload. Target at most 180 s added
  cold job wall time; a 5-minute hard job timeout prevents a hung smoke run.
  No promise that these budgets are achievable. A separate parallel job adds
  PR latency only when its completion exceeds the existing required jobs (plus
  queue delay); serial placement would add its whole duration.
- Browser downloads are not free on cache hits: Playwright's [CI guidance](https://playwright.dev/docs/ci)
  warns cache restoration can take comparable time and OS dependencies remain.
  Record download/cache behavior rather than extrapolating from the local Mac.
- Qualification: 30 unchanged local runs and 30 on the target CI image, zero
  unexplained first-attempt failures, record p50/p95 and first-attempt outcomes.
  Zero failures in 30 is weak statistical evidence, not proof of a low flake rate.
  Capture screenshot, console/stack, URL, seed and versions on failure; evaluate
  [trace capture](https://playwright.dev/docs/trace-viewer) overhead explicitly.
  At most one diagnostic rerun, keeping the original failure visible and counting
  restart/setup/runtime in cost. [Retries](https://playwright.dev/docs/test-retries)
  can turn a failure into a flaky pass; do not hide that outcome.
- Proposed effort cap: two engineer-days for an authorized evaluation, with a
  named maintainer before adoption. Track actual setup and diagnosis time;
  budget maintenance at one hour/month initially. No owner is assigned by this
  report. Stop if native assertions add no distinct protection, sandbox/Mox
  isolation fails, the cost caps are exceeded, or reliability requires recurrent
  timeout increases/retries. Revert to manual checks instead of expanding scope.

If qualified, start separately invoked, then optional selective CI for organizer
controls, shared CSS/components, relevant hooks, endpoint/auth plumbing and
browser dependency changes. Keep all fast checks required and unchanged. Require
an explicit decision before making browser checks a merge gate.

The no-adoption option is complete: preserve current tests, use a release checklist
for Tab/Space/arrows and focus across organizer create/edit/group forms; inspect
valid, absent and failed covers with long content at mobile/desktop widths; verify
mobile drawer focus and live navigation. Record failures as product bugs and
revisit automation only when repeated manual cost or escaped regressions justify it.
