# Browser scenarios

A small Chromium suite for behavior the fast Cucumber suite cannot exercise: native keyboard defaults, JavaScript hooks, browser time-zone detection, image decoding, focus, inert content, and responsive layout. Domain rules and ordinary LiveView interactions stay in `test/features`.

## Run locally

Use the usual `.test.env` with a dedicated test database and an unused HTTP port. Each scenario rolls back its database fixtures and removes its uploaded files.

One-time setup from the repository root:

```sh
MIX_ENV=test mix deps.get
MIX_ENV=test mix assets.setup
npm ci --prefix assets
PLAYWRIGHT_BROWSERS_PATH="$PWD/_build/browser/browsers" assets/node_modules/.bin/playwright install chromium --only-shell
```

On Linux, add `--with-deps` to the Playwright install command to install the required system libraries.

```sh
mix test.browser
mix test.browser --only calendar_browser
```

The command builds the actual app assets, starts the test endpoint and Chromium, and runs only `test/browser`. On machines with many CPU cores and a small database pool, use `ERL_FLAGS='+S 4:4' mix test.browser` to limit BEAM schedulers. Ordinary `mix test` and `mix precommit` do not start Chromium; run the browser command separately when changing browser behavior.

## Coverage

| Feature | Browser-specific acceptance check |
| --- | --- |
| Home location | ArrowDown/Enter select a suggestion without a native form submission |
| Calendar | Actual `Intl` time-zone detection moves a late Denver huddl to the next New York calendar day |
| Organizer | Native Tab, arrow keys, Space, visible focus, and switch state survive LiveView patches |
| Huddl photos | Mixed-batch rejection, corrupt-image feedback, native Tab access to upload, keyboard carousel, dialog focus wrapping and restoration, and mobile gallery placement |
| Profile picture | Real file upload and image decode; removal button hit testing and pointer confirmation; dialog Tab containment, Escape, and focus restoration |
| Mobile navigation | 320px drawer, native focus wrapping, inert background, dismissal and navigation |
| Group cover | Valid, missing, and failed images; long details fit at 320px and on desktop |

Browser scenarios live in `features/`, their steps in `steps/`, and Cucumber hooks in `support/`. `browser_features_test.exs` supplies explicit feature/step/support globs to Cucumber. The existing fast root and its steps are loaded only by the normal test runner. No Cucumber fork or second library is needed. Use descriptive tags such as `@calendar_browser`; `@browser` conflicts with the adapter's browser-selection option.

Keep this suite serial: its SQL sandbox ownership and global Mox stubs are shared with HTTP/LiveView processes. Do not add `@async` or extra workers without changing that fixture strategy. Each scenario gets a fresh browser context. Authentication uses a signed session cookie; these are not sign-in UI tests. Places/geocoding are deterministic stubs, with no external service credentials needed. Browser contexts use `America/New_York`; `@mobile` selects a 320×720 viewport.

Browser setup uses the adapter's public `Case.do_setup_all/1` and `Case.do_setup/1` functions because Cucumber creates the ExUnit modules. The hook supplies a compatible module name for diagnostic filenames, preserving the scenario name. SQL sandbox HTTP metadata and the LiveView allowance hook are enabled only in test builds, before authentication queries.

## CI and diagnostics

The **Browser scenarios (Chromium)** job runs separately on every PR, including stacked PRs, and every push to `main`, alongside the fast tests. It installs the pinned Playwright version from `assets/package-lock.json`, Chromium headless shell, and Linux libraries. It uses one worker, a two-minute test-step timeout, and no automatic retries. Dependency compilation is cached; browser binaries and diagnostics are not part of that cache.

Screenshots and traces are captured for every attempt under `_build/browser/screenshots` and `_build/browser/traces`. Failed CI runs upload these directories as `browser-failure-diagnostics` for seven days. Inspect the original failure before rerunning:

```sh
assets/node_modules/.bin/playwright show-trace _build/browser/traces/<trace.zip>
```

Assertions wait for observable browser state instead of sleeping. JavaScript used in steps observes layout, image loading, or native form submissions; it does not implement the application behavior. The failed-cover scenario intentionally requests a missing image, so its expected 404 is not a suite-wide console failure.
