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

      # Silence warnings about unused variables in this module's functions
      @compile {:nowarn_unused_vars, step: 2}
      
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

  # Enhanced defstep macro with multiple supported signatures

  # Case 1: defstep "pattern" do ... end (original style)
  defmacro defstep(pattern, [do: block]) do
    quote do
      @cucumber_steps {unquote(pattern), {nil, nil, unquote(Macro.escape(block))}}
    end
  end

  # Case 2: defstep "pattern", args do ... end (new style)
  defmacro defstep(pattern, args, [do: block]) do
    quote do
      @cucumber_steps {unquote(pattern), {unquote(Macro.escape(args)), nil, unquote(Macro.escape(block))}}
    end
  end

  # Case 3: defstep "pattern", args, context do ... end (new style)
  defmacro defstep(pattern, args, context, [do: block]) do
    quote do
      @cucumber_steps {unquote(pattern), {unquote(Macro.escape(args)), unquote(Macro.escape(context)), unquote(Macro.escape(block))}}
    end
  end
  
  # __before_compile__ generates step/2 function for matching and executing steps
  defmacro __before_compile__(env) do
    steps = Module.get_attribute(env.module, :cucumber_steps) || []

    quote do
      # Main step dispatch function that tries to match patterns and extracts arguments
      def step(context, %Gherkin.Step{text: text}) do
        result = 
          Enum.find_value(unquote(Macro.escape(steps)), fn
            {pattern, {args_pattern, context_pattern, block}} ->
              # Compile the pattern at runtime
              compiled_pattern = Cucumber.Expression.compile(pattern)
              
              case Cucumber.Expression.match(text, compiled_pattern) do
                {:match, args} -> 
                  # Execute the step function with extracted arguments
                  try do
                    result = case {args_pattern, context_pattern} do
                      {nil, nil} ->
                        # Original style: make context and args available as vars
                        var!(context) = context
                        var!(args) = args
                        unquote(quote do: block)
                        
                      {args_pat, nil} when not is_nil(args_pat) ->
                        # New style: args explicitly named
                        unquote(quote do
                          args_pat = args
                          block
                        end)
                        
                      {args_pat, ctx_pat} ->
                        # New style: both args and context explicitly named
                        unquote(quote do
                          args_pat = args
                          ctx_pat = context
                          block
                        end)
                    end
                    
                    {:ok, result}
                  rescue
                    e -> 
                      # Capture the error but preserve the stacktrace for better debugging
                      {:error, {e, __STACKTRACE__}}
                  end
                  
                :no_match -> 
                  nil
              end
          end)

        case result do
          {:ok, new_context} when is_map(new_context) -> 
            # If the step returns a map, use it as the new context
            new_context
            
          {:ok, _other_value} -> 
            # For other return values, just keep the existing context
            context
            
          {:error, {error, stacktrace}} ->
            # Re-raise the error with the original stacktrace
            reraise error, stacktrace
            
          nil -> 
            # No matching step found
            raise "No matching step definition found for: #{inspect(text)}"
        end
      end
    end
  end
end
