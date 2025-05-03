defmodule CucumberMacroTest do
  # Remove the compile directive since we'll be explicit with parameters
  use Cucumber, feature: "simple.feature"

  defstep "a simple step", _args, context do
    Map.put(context, :simple, true)
  end
end
