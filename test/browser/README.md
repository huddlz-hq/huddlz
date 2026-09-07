# Throwaway Cucumber browser prototype

Question: can the installed Cucumber 1.0.0 run a small, separately invoked real-browser suite without moving the fast features?

**Yes.** This branch proves one authenticated, native-keyboard scenario with PhoenixTest.Playwright 0.16.0 / Playwright 1.62.0. It is a prototype for #420, not an adoption decision or a CI performance result. No CI workflow changed. Start point: `f7dc8fab` (the separate search/order test improvements).

## Run it

Use a worktree-local `.test.env` with a dedicated scratch database and unused port. This run used database `huddlz_browser_prototype_20d8`, port `4421`, pool size `10`, PostgreSQL 17.10 and existing test signing secrets. Do not point this at a shared development or production database.

One-time setup from the repository root:

```sh
MIX_ENV=test mix deps.get
npm ci --prefix assets
PLAYWRIGHT_BROWSERS_PATH="$PWD/_build/browser-prototype/browsers" assets/node_modules/.bin/playwright install chromium --only-shell
```

Run the prototype (builds the actual assets, starts the app and one Chromium session, runs one scenario, saves diagnostics, and exits):

```sh
ERL_FLAGS='+S 4:4' mix test.browser
```

The scheduler cap keeps the local pool usage reasonable; it is not a repository-wide setting. Normal `mix test` continues to load `test/test_helper.exs` and the existing fast scenarios. The prototype adds dependency compilation to a cold checkout but no browser startup to ordinary tests.

## How the folders work

```text
test/features/                         existing fast features/steps/hooks
test/test_helper.exs                    existing fast entry point, unchanged
test/browser/test_helper.exs            browser supervisor and diagnostics
test/browser/browser_features_test.exs  Cucumber discovery entry point
test/browser/features/                 one browser-only feature
test/browser/steps/                     native browser actions/assertions
test/browser/support/                  scenario fixture setup
```

`mix test.browser` starts a child Mix invocation with `HUDDLZ_BROWSER_TEST=1`. `mix.exs` selects `test/browser` as its test path. Its runner calls `Cucumber.compile_features!` with explicit `features`, `steps`, and `support` glob lists. No fast steps are loaded into that run. Ordinary Mix test discovery explicitly excludes the browser runner using `test_load_filters`.

The installed `Cucumber.Discovery.discover/1` also accepted both feature globs in one call and returned **42 fast feature files plus one browser feature file**. Running both suites in one process is deliberately not the prototype's design.

Three integration details surfaced:

1. A helper that only calls `compile_features!` is insufficient when the browser folder contains no `_test.exs` files: Mix reports no tests. The small runner file supplies that entry point.
2. `test_ignore_filters` does not override files matching `test_load_filters`. The explicit load filter is necessary to avoid accidentally discovering the browser runner in the fast suite.
3. `@browser` becomes `browser: true` in ExUnit context and collides with the adapter's browser selection. This prototype uses `@browser_smoke`. Cucumber's generated module atoms also lack the `Elixir.` prefix expected by the adapter's diagnostic filename code; the hook passes its own module only to the driver setup, preserving the scenario name and original Cucumber context.

Cucumber generates its own ExUnit cases, so the hook calls the adapter's public `Case.do_setup_all/1` and `Case.do_setup/1` functions. No Cucumber changes or forks were needed. [Cucumber options](https://cucumber.hexdocs.pm/Cucumber.html#compile_features!/1), [adapter setup functions](https://phoenix-test-playwright.hexdocs.pm/PhoenixTest.Playwright.Case.html).

## What the browser adds

The feature types a stubbed home-location query, presses ArrowDown and Enter, asserts the selected location and LiveView feedback, and observes that no native form submission occurred. It uses actual keyboard input and the application's JavaScript hook, not `render_keydown` or synthetic LiveView messages. Its only injected JavaScript observes native form submissions; it does not implement the app behavior.

Temporarily removing the hook's Enter `preventDefault()` made the browser scenario fail after selecting with Enter. All **15 existing fast profile scenarios still passed** with the same JavaScript mutation. Restoring the hook made the browser scenario pass. The mutation is not retained. This demonstrates one distinct coverage gain, not a reason to move the other profile scenarios.

Authentication uses a generated user and a signed session cookie with the same Ash JWT/session options as the app. It proves an authenticated browser visit, not the sign-in UI. HTTP sandbox middleware and LiveView user-agent metadata are enabled only in the test configuration; the allowance hook runs before Ash authentication queries. Normal tests tolerate absent metadata. Browser contexts close before the adapter releases the sandbox owner.

The prototype is **serial only**: a shared SQL sandbox and global Mox stubs cover HTTP/LiveView processes in one invocation. Do not add `@async` or a second worker without replacing that fixture strategy. Places responses remain deterministic, and the browser does not call Google. No database seeds, live third-party credentials, or production data are required.

## Measurements and limits

Measured 2026-09-07 on macOS 26.6.2 ARM, 18 logical CPUs / 128 GiB RAM, Elixir 1.20.2 / OTP 29, Node 26.8.1, with four BEAM schedulers. Dependencies, Chromium, build artifacts and database schema were warm. These are local measurements, not cold-install or CI estimates.

Five sequential runs used `/usr/bin/time -p env ERL_FLAGS='+S 4:4' mix test.browser`, with screenshots and traces enabled on every attempt. The full wall times were **5.74, 5.29, 5.37, 5.32, and 5.26 seconds** (median **5.32 s**, range **5.26–5.74 s**). ExUnit reported **2.1–2.3 s**. These totals include asset build, application/browser startup, scenario execution, screenshots, traces and teardown. Five passes provide only an initial repeatability check, not a flake-rate qualification.

The full normal suite passed **1,789 tests** with the prototype's browser-binary directory temporarily renamed out of the configured location. The directory was restored afterward. The six existing Node tests also passed. `mix precommit` completed compilation, formatting and tests; its two new Credo alias suggestions were corrected and lint rerun separately. A post-run query found zero retained user fixtures in the dedicated database. Existing missing-form-id/teardown diagnostics remain outside this prototype's scope.

Chromium headless shell plus FFmpeg occupied about 199 MiB on this Mac; the Playwright Node packages about 18 MiB. Linux OS dependencies, cold download/build time, concurrent sessions, alternate browsers, CI execution, and maintenance over upgrades remain unmeasured. The earlier research budgets remain proposals.

Diagnostics are written under `_build/browser-prototype/screenshots` and `traces` (ignored by Git). Open a trace with `assets/node_modules/.bin/playwright show-trace <trace.zip>`. Preserve first-attempt failures; this prototype performs no automatic retries. Both successful and failed attempts produce diagnostics so the prototype can inspect teardown as well as assertion failures.

Keep this branch out of main until an adoption decision. If retained, next steps are to choose an owner, validate fixtures and teardown under the intended concurrency, and measure a separately invoked Linux/CI run before adding a job or merge gate.
