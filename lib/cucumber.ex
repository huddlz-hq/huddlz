defmodule Cucumber do
  @moduledoc """
  Macro for Gherkin-based testing in Elixir.
  Usage:
    use Cucumber, feature: "user_joins_event.feature"
    use Cucumber, feature: "user_joins_event.feature", tags: ["smoke", "auth"]
  """

  defmacro __using__(opts) do
    feature_file = Keyword.fetch!(opts, :feature)
    filter_tags = Keyword.get(opts, :tags, [])
    feature = Gherkin.Parser.parse(File.read!(Path.join(["test", "features", feature_file])))

    # Filter scenarios based on tags if filter_tags is provided
    filtered_scenarios =
      if filter_tags == [] do
        feature.scenarios
      else
        # Keep scenarios that have at least one matching tag
        Enum.filter(feature.scenarios, fn scenario ->
          Enum.any?(scenario.tags, &(&1 in filter_tags)) ||
            Enum.any?(feature.tags, &(&1 in filter_tags))
        end)
      end

    # Generate setup block
    setup_block =
      if feature.background do
        quote do
          setup context do
            Enum.reduce(unquote(Macro.escape(feature.background.steps)), context, fn step, ctx ->
              Cucumber.apply_step(__MODULE__, ctx, step)
            end)
          end
        end
      else
        nil
      end

    # Generate test blocks for each filtered scenario
    test_blocks =
      for scenario <- filtered_scenarios do
        quote do
          test unquote(scenario.name), context do
            Enum.reduce(unquote(Macro.escape(scenario.steps)), context, fn step, ctx ->
              Cucumber.apply_step(__MODULE__, ctx, step)
            end)
          end
        end
      end

    quote do
      use ExUnit.Case, async: true
      import Cucumber, only: [defstep: 2]

      # Register module attribute for step definitions
      Module.register_attribute(__MODULE__, :cucumber_steps, accumulate: true)
      @before_compile Cucumber

      describe unquote(feature.name) do
        unquote(setup_block)
        unquote_splicing(test_blocks)
      end
    end
  end

  # Helper function to call step/2 in the test module
  def apply_step(module, context, step) do
    apply(module, :step, [context, step])
  end

  # defstep macro - accumulates step definitions in @cucumber_steps
  defmacro defstep(pattern, do: block) do
    quote do
      @cucumber_steps {unquote(pattern), unquote(Macro.escape(block))}
    end
  end

  # __before_compile__ generates step/2 function heads for all defined steps
  defmacro __before_compile__(env) do
    steps = Module.get_attribute(env.module, :cucumber_steps) || []

    # Generate step/2 function heads for all step patterns
    step_defs =
      for {pattern, block} <- steps do
        quote do
          def step(context, %Gherkin.Step{text: unquote(pattern)}) do
            var!(context) = context
            unquote(block)
          end
        end
      end

    # Default step/2 function for unmatched steps
    default_step =
      quote do
        def step(_context, %Gherkin.Step{text: text}) do
          raise "No matching step definition found for: #{inspect(text)}"
        end
      end

    # Return all function definitions
    quote do
      unquote_splicing(step_defs)
      unquote(default_step)
    end
  end
end
