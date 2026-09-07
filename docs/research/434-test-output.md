# Test output investigation (#434)

Baseline: main `a13ef31f`, 2026-09-07, macOS, Elixir 1.20.2 / OTP 29.0.3
(the versions in `.mise.toml` and CI). Dependencies and build artifacts were
copied into this worktree, then the application recompiled. Tests used a
separate `huddlz_test_434_78c4` database and the example test mailer settings.

## Baseline and findings

`ERL_FLAGS='+S 4:4' mix test --seed 488441` exited 0: 1,789 tests passed
(including one doctest). Captured stdout/stderr contained 767 lines / 45,754
bytes, including 24 missing-form-ID warnings and three error log entries.

| Source | Classification | Disposition |
| --- | --- | --- |
| Location-modal forms with `phx-change` but no ID | Application defect: LiveView cannot identify forms for recovery | Add stable IDs to the shared huddl location modal and the group location modal. Strengthen existing rendered-form assertions. |
| Organize LiveView database ownership errors during teardown | Test setup defect | Keep Cucumber's sandbox owner alive until ExUnit stops supervised LiveViews, then stop the owner in `on_exit`. |
| Default 36 concurrent cases versus ten database connections | Local environment capacity | Use four schedulers (eight concurrent cases) for verification. No production pool or logging changes. |
| Sandbox TCP restrictions | Execution environment | Run with local TCP access; no application workaround. |
| Intermittent PostgreSQL `too_many_connections` during a focused attempt | Shared server capacity | Retry sequentially after other runs finish; do not stop other tasks or reset their databases. |
| Compiler/deprecation warnings | None observed in the application recompile | Cached dependency builds do not establish that every dependency compiles quietly from scratch. |
| Expected failure-path logs | Already handled by existing `ExUnit.start(capture_log: true)` | Leave capture behavior unchanged; captured logs remain available on failed tests. |
| Debug output | None found in the baseline or `IO.inspect` / `IO.puts` / `dbg` search of `lib` and `test` | No change. |

The first unrestricted baseline used default schedulers and exited 2 with
490 failures from pool exhaustion. This prompted the bounded-concurrency
baseline above. The earlier sandbox-restricted attempt exited 1 before tests.

## Root cause and focused verification

The two new form selectors failed before their corresponding ID was added;
both passed afterward. Existing save-address tests also passed through both
forms. The IDs are rendered contracts; browser reconnect behavior was not
separately exercised.

`ERL_FLAGS='+S 4:4' mix test --only organizer_permissions --seed 488441`
passed all 11 scenarios before the hook fix but emitted five error entries
(268 lines / 19,876 bytes). After the fix it passed with no warning/error
entries (10 lines / 292 bytes). This command is the teardown regression
probe; inspect stderr as well as the exit status, because teardown errors did
not fail the scenarios.

Installed Ecto SQL 3.14.0 documents `Sandbox.start_owner!/2` specifically as
the remedy for LiveView processes outliving a test process. Installed LiveView
1.2.11 starts its channels under the ExUnit test supervisor. Cucumber 1.0.0
runs before hooks in the scenario test process. The repository hook used
`Sandbox.checkout/1`, so that process's exit released the connection before
LiveViews finished queued membership refreshes. This is a repository setup
problem, not a reason to patch or upgrade those dependencies. The separate
owner preserves per-scenario isolation and requires no log suppression.

## Coordination and limits

#411's Discover form fix is already merged in PR #424; these are different
forms. #125's preference validation is merged in PR #428, while its mailer
migration remains deferred. No mailer change is needed for this reproduction.
No dependency versions, production logging, warning thresholds, capture
settings, or test selection defaults were changed.

The machine's default concurrency can still exceed a ten-connection test
pool. Size local test concurrency for the available database, for example
with `ERL_FLAGS='+S 4:4'`; do not interpret connection-capacity errors as
expected test noise. Dependency cold-build warnings remain unassessed.

## Final verification

`ERL_FLAGS='+S 4:4' mix precommit` exited 0 with seed 375297. All 1,789
tests passed; compilation with warnings as errors and strict Credo passed.
The entire precommit output was 16 lines / 2,334 bytes, with zero missing-ID
warnings and zero warning/error log entries, compared with the baseline's
767 lines / 45,754 bytes. This includes the full suite as well as precommit's
additional checks; it is not a separate second full-suite run.
