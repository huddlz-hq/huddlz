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

      # Import only the defstep macros that we actually define
      import Cucumber, only: [defstep: 2, defstep: 3]

      # Register module attribute for cucumber patterns
      Module.register_attribute(__MODULE__, :cucumber_patterns, accumulate: true)
      @before_compile Cucumber

      describe unquote(feature.name) do
        unquote(setup_block)
        unquote_splicing(test_blocks)
      end
    end
  end

  # Helper function to call step/2 in the test module with merged args and context
  def apply_step(module, context, %Gherkin.Step{text: text}) do
    # Extract parameters using the Expression module
    patterns = module.__cucumber_patterns__()

    # Find a matching pattern and extract args
    result =
      Enum.find_value(patterns, fn pattern_info ->
        {pattern_text, _} = pattern_info
        compiled_pattern = Cucumber.Expression.compile(pattern_text)

        case Cucumber.Expression.match(text, compiled_pattern) do
          {:match, args} -> {pattern_text, args}
          :no_match -> nil
        end
      end)

    case result do
      {pattern, args} ->
        # Merge args into context and call step/2 with the pattern
        context_with_args = Map.put(context, :args, args)
        apply(module, :step, [context_with_args, pattern])

      nil ->
        # No matching pattern found
        raise "No matching step definition found for: #{inspect(text)}"
    end
  end

  # New simpler API: defstep "pattern", context do ... end
  defmacro defstep(pattern, context \\ nil, do: block) do
    quote do
      # Register the pattern in a module attribute for lookup
      @cucumber_patterns {unquote(pattern), unquote(Macro.escape(block))}

      # Generate a step/2 function with pattern as second parameter and merged context+args
      def step(context_value, unquote(pattern)) do
        # Bind context to the actual value (already contains args)
        unquote(context || quote(do: context)) = context_value
        unquote(block)
      end
    end
  end

  # __before_compile__ generates the function to return cucumber patterns
  defmacro __before_compile__(env) do
    patterns = Module.get_attribute(env.module, :cucumber_patterns) || []

    quote do
      # Helper function to get defined patterns for lookup
      def __cucumber_patterns__ do
        unquote(Macro.escape(patterns))
      end

      # Fallback step function for unmatched patterns
      def step(_context, _pattern) do
        raise "No matching step definition found"
      end
    end
  end
end
