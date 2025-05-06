defmodule SignupWithMagicLinkTest do
  use ExUnit.Case
  # This test just ensures our feature file gets loaded
  # The actual step definitions are in test/features/steps/signup_with_magic_link_steps_test.exs

  test "feature file exists" do
    # This is just a wrapper test to make sure the feature file is loaded by ExUnit
    assert File.exists?("test/features/signup_with_magic_link.feature")
  end
end
