# Outside-In Behavior-Driven Testing

huddlz develops features from observable behavior inward. Behavior tests are
the primary specification and the starting point for feature work: describe
what a person or external caller should observe in Cucumber/Gherkin before
writing the implementation, then use that scenario to drive a vertical slice
through the system.

Keep scenarios in the language of the domain. A scenario should explain the
capability or rule without describing LiveView events, database writes, module
calls, or other implementation details.

## The three testing rings

The test suite has three concentric rings, ordered from outside to inside.

### 1. Behavior tests

Cucumber scenarios in `test/features/*.feature` express user-observable or
externally observable behavior with Given/When/Then steps. Step definitions
live in `test/features/step_definitions/`, with shared setup in
`test/features/support/`.

Start feature development here. Write one meaningful scenario, see it fail,
implement the smallest vertical slice that makes it pass, and repeat.

A Cucumber scenario does not have to drive every rule through a full browser
or UI path. Use PhoenixTest when the behavior is genuinely about the web
experience. For domain, notification, or other non-UI behavior, a step may use
the appropriate public application boundary instead. The scenario must remain
business-readable and verify an observable outcome regardless of the seam it
drives.

### 2. Integration tests

Elixir integration tests exercise collaborations through public boundaries.
They live primarily under `test/huddlz/` and `test/huddlz_web/` and use the
project's ExUnit case modules, including `Huddlz.DataCase`,
`HuddlzWeb.ConnCase`, and `HuddlzWeb.ApiCase`, where appropriate.

Add integration tests when they provide faster feedback than a behavior
scenario, isolate a boundary failure, or protect a contract such as an Ash
action, policy, API, controller, LiveView, worker, or notification flow.

### 3. Focused unit tests

Use focused ExUnit tests for complex or high-value logic that benefits from
fast, precise protection. Examples include calculations, transformations,
parsing, recurrence rules, token handling, and other logic with meaningful
edge cases.

Unit tests are not automatically required for coverage. Add them when the
smaller seam makes failures easier to diagnose or protects logic more clearly
than the outer rings alone.

## How the rings work together

The ring order describes the order of intent and design, not a required ratio
of behavior, integration, and unit tests. Begin with the behavior that matters,
then add lower-level tests only where they contribute distinct confidence,
feedback speed, or diagnostic value.

Intentional overlap is acceptable. A Cucumber scenario can specify a huddl
workflow while an integration test protects its authorization boundary and a
unit test covers a difficult recurrence edge case. Avoid only overlap that
repeats the same assertions against implementation details without adding
distinct protection.

Prefer stable behavior and contracts over internal structure. Tests should
survive refactoring when externally observable behavior is unchanged. Avoid
assertions about private functions, internal call order, incidental markup, or
database representation unless that detail is itself a supported contract.

## Development workflow

1. Describe the next user-observable behavior in a focused Gherkin scenario.
2. Choose the public seam that demonstrates that behavior at the appropriate
   layer.
3. Run the relevant test and confirm it fails for the expected reason.
4. Implement the smallest vertical slice that makes it pass.
5. Add integration or unit tests when they provide distinct protection.
6. Continue in small red-to-green slices until the behavior is complete.

During development, run the narrowest relevant ExUnit test with:

```sh
mix test path/to/test.exs
mix test path/to/test.exs:line
```

Run `mix test` when broader suite feedback is useful. When the change is
complete, run the full project validation once:

```sh
mix precommit
```

`mix precommit` runs compilation with warnings as errors, formatting,
dependency cleanup, the test suite, and Credo. Do not run all of those commands
separately by default; rerun an individual command when diagnosing or fixing a
specific validation failure.
