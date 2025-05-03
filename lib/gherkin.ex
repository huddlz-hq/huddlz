defmodule Gherkin.Feature do
  @moduledoc """
  Represents a parsed Gherkin feature file (minimal subset).
  """
  defstruct name: "", description: "", background: nil, scenarios: []
end

defmodule Gherkin.Background do
  @moduledoc """
  Represents a Gherkin Background section.
  """
  defstruct steps: []
end

defmodule Gherkin.Scenario do
  @moduledoc """
  Represents a Gherkin Scenario section.
  """
  defstruct name: "", steps: []
end

defmodule Gherkin.Step do
  @moduledoc """
  Represents a Gherkin step (Given/When/Then/And/But/*).
  """
  defstruct keyword: "", text: ""
end

# Initial parser module scaffold

defmodule Gherkin.Parser do
  @moduledoc """
  Minimal Gherkin 6 parser (Feature, Background, Scenario, Step).
  """

  alias Gherkin.{Feature, Background, Scenario, Step}

  @doc """
  Parses a Gherkin feature file from a string.
  Returns %Feature{} struct.
  """
  def parse(gherkin_string) do
    lines = String.split(gherkin_string, "\n", trim: true)
    lines = Enum.map(lines, &String.trim/1)
    
    # Find Feature line
    [feature_line | rest] = Enum.drop_while(lines, &(&1 == ""))
    [_, feature_name] = String.split(feature_line, ":", parts: 2)
    feature_name = String.trim(feature_name)

    # Find Background (optional)
    {background, after_bg} =
      case Enum.split_while(rest, &(!String.starts_with?(&1, "Scenario:"))) do
        {bg_lines, [scenario_line | scenario_rest]} ->
          has_background = Enum.any?(bg_lines, &String.starts_with?(&1, "Background:"))
          if has_background do
            bg_steps =
              bg_lines
              |> Enum.drop_while(&(&1 == "" or String.starts_with?(&1, "Background:")))
              |> Enum.map(fn step_line ->
                [keyword, text] = Regex.run(~r/^(Given|When|Then|And|But|\*) (.+)$/, step_line, capture: :all_but_first)
                %Step{keyword: keyword, text: text}
              end)
            {%Background{steps: bg_steps}, [scenario_line | scenario_rest]}
          else
            {nil, [scenario_line | scenario_rest]}
          end
        _ -> {nil, rest}
      end

    # Parse all scenarios and their steps
    scenarios =
      after_bg
      |> Enum.reduce({[], nil, []}, fn line, {scenarios, current_scenario, steps} ->
        if String.starts_with?(line, "Scenario:") do
          if current_scenario do
            [_, scenario_name] = String.split(current_scenario, ":", parts: 2)
            scenario_name = String.trim(scenario_name)
            scenario = %Scenario{name: scenario_name, steps: Enum.reverse(steps)}
            {scenarios ++ [scenario], line, []}
          else
            {scenarios, line, []}
          end
        else
          case Regex.run(~r/^(Given|When|Then|And|But|\*) (.+)$/, line, capture: :all_but_first) do
            [keyword, text] ->
              {scenarios, current_scenario, [%Step{keyword: keyword, text: text} | steps]}
            _ -> {scenarios, current_scenario, steps}
          end
        end
      end)
      |> (fn {scenarios, current_scenario, steps} ->
            # Add the last scenario if present
            if current_scenario do
              [_, scenario_name] = String.split(current_scenario, ":", parts: 2)
              scenario_name = String.trim(scenario_name)
              scenario = %Scenario{name: scenario_name, steps: Enum.reverse(steps)}
              scenarios ++ [scenario]
            else
              scenarios
            end
          end).()

    %Feature{
      name: feature_name,
      description: "",
      background: background,
      scenarios: scenarios
    }
  end
end
