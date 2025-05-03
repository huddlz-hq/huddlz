defmodule CucumberSmokeTest do
  use Cucumber, feature: "cucumber_smoke.feature"

  defstep "the system is ready", _context do
    :ok
  end

  defstep "I run a smoke test", _context do
    :ok
  end

  defstep "it should pass", _context do
    assert true
    :ok
  end
end
