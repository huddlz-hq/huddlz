# Quick Resume Guide for Issue #19

## Status: ON HOLD - Waiting for Issue #20 (PhoenixTest)

## The Real Goal
**Create standard testing patterns** to stop developers from "thrashing on implementation" for common test scenarios.

Example problem: "How do I check a flash message?" shouldn't require figuring out implementation details each time.

## Key Decision
PhoenixTest (issue #20) must be implemented first because:
- It standardizes LiveView vs dead view testing
- Shared steps built on PhoenixTest will be cleaner
- Less rework needed

## When Resuming
1. Verify PhoenixTest is implemented
2. Review how PhoenixTest changed existing tests
3. Start with `/build issue=19` (will auto-detect task 1)
4. Focus on creating standard patterns, not just removing duplication

## Remember
- Cucumber 0.2.0 adds shared `defstep` capability
- Start with "resources" and "UI" categories
- Let patterns emerge - don't over-engineer