defmodule CompleteSignupFlowTest do
  use ExUnit.Case
  # This test just ensures our feature file gets loaded
  # The actual step definitions are in test/features/steps/complete_signup_flow_steps_test.exs

  test "feature file exists" do
    # This is just a wrapper test to make sure the feature file is loaded by ExUnit
    assert File.exists?("test/features/complete_signup_flow.feature")
  end
end
