defmodule Huddlz.RateLimitTest do
  # async: false — the limiter uses a process-global ETS table shared across the node.
  use ExUnit.Case, async: false

  import Huddlz.RateLimitTestHelper

  alias Huddlz.RateLimit

  @scale :timer.minutes(1)

  setup do
    enable_rate_limiting()
  end

  defp unique_key, do: "test:#{System.unique_integer([:positive])}"

  test "allows hits up to the limit, then denies with a retry-after" do
    key = unique_key()

    for _ <- 1..3 do
      assert {:allow, _count} = RateLimit.hit(key, @scale, 3)
    end

    assert {:deny, retry_after_ms} = RateLimit.hit(key, @scale, 3)
    assert retry_after_ms > 0
  end

  test "each key has an independent bucket" do
    exhausted = unique_key()
    fresh = unique_key()

    assert {:allow, _} = RateLimit.hit(exhausted, @scale, 1)
    assert {:deny, _} = RateLimit.hit(exhausted, @scale, 1)

    # A different key is unaffected by the exhausted one.
    assert {:allow, _} = RateLimit.hit(fresh, @scale, 1)
  end

  test "increments applied from another node count toward the limit" do
    key = unique_key()

    # Simulate what the Listener does when it hears another node's hits.
    RateLimit.Local.inc(key, @scale, 2)

    # Two remote + one local = at the limit of 3.
    assert {:allow, _} = RateLimit.hit(key, @scale, 3)
    assert {:deny, _} = RateLimit.hit(key, @scale, 3)
  end

  test "when disabled, every hit is allowed and nothing is counted" do
    Application.put_env(:huddlz, :rate_limit_enabled, false)
    key = unique_key()

    # Well past a limit of 1 — the kill-switch means no counting and no denial.
    for _ <- 1..10 do
      assert {:allow, 0} = RateLimit.hit(key, @scale, 1)
    end
  end
end
