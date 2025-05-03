defmodule CucumberMacroTest do
  # Silence warnings about unused variables in the step function
  @compile {:nowarn_unused, {:vars, [:context, :args]}}
  use Cucumber, feature: "simple.feature"

  defstep "a simple step" do
    Map.put(context, :simple, true)
  end
end
