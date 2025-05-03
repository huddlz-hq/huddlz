defmodule Gherkin.Feature do
  @moduledoc """
  Represents a parsed Gherkin feature file (minimal subset).
  """
  defstruct name: "", description: "", background: nil, scenarios: [], tags: []
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
  defstruct name: "", steps: [], tags: []
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

    # Extract feature tags and name
    {feature_tags, feature_line, rest} = extract_tags_and_element(lines, "Feature:")
    [_, feature_name] = String.split(feature_line, ":", parts: 2)
    feature_name = String.trim(feature_name)

    # Find Background (optional)
    {background, after_bg} =
      case Enum.split_while(rest, fn line ->
             !String.starts_with?(line, "Scenario:") && !String.starts_with?(line, "@")
           end) do
        {bg_lines, rest_with_scenarios} ->
          has_background = Enum.any?(bg_lines, &String.starts_with?(&1, "Background:"))

          if has_background do
            bg_steps =
              bg_lines
              |> Enum.drop_while(&(&1 == "" or String.starts_with?(&1, "Background:")))
              |> Enum.map(fn step_line ->
                [keyword, text] =
                  Regex.run(~r/^(Given|When|Then|And|But|\*) (.+)$/, step_line,
                    capture: :all_but_first
                  )

                %Step{keyword: keyword, text: text}
              end)

            {%Background{steps: bg_steps}, rest_with_scenarios}
          else
            {nil, rest_with_scenarios}
          end

        _ ->
          {nil, rest}
      end

    # Parse all scenarios with their tags and steps
    scenarios =
      parse_scenarios(after_bg)

    %Feature{
      name: feature_name,
      description: "",
      background: background,
      scenarios: scenarios,
      tags: feature_tags
    }
  end

  # Helper function to parse scenarios with their tags
  defp parse_scenarios(lines) do
    {scenarios, current_scenario, current_tags, steps} =
      Enum.reduce(lines, {[], nil, [], []}, fn line,
                                               {scenarios, current_scenario, current_tags, steps} ->
        cond do
          # Tag line
          String.starts_with?(line, "@") ->
            if current_scenario do
              # Save previous scenario before starting a new one with tags
              [_, scenario_name] = String.split(current_scenario, ":", parts: 2)
              scenario_name = String.trim(scenario_name)

              scenario = %Scenario{
                name: scenario_name,
                steps: Enum.reverse(steps),
                tags: current_tags
              }

              {scenarios ++ [scenario], nil, extract_tags(line), []}
            else
              # Tags before first scenario
              {scenarios, current_scenario, extract_tags(line), steps}
            end

          # Scenario line
          String.starts_with?(line, "Scenario:") ->
            if current_scenario do
              # Save previous scenario before starting a new one
              [_, scenario_name] = String.split(current_scenario, ":", parts: 2)
              scenario_name = String.trim(scenario_name)

              scenario = %Scenario{
                name: scenario_name,
                steps: Enum.reverse(steps),
                tags: current_tags
              }

              {scenarios ++ [scenario], line, [], []}
            else
              # First scenario or scenario after tags
              {scenarios, line, current_tags, []}
            end

          # Step line
          Regex.match?(~r/^(Given|When|Then|And|But|\*) /, line) ->
            [keyword, text] =
              Regex.run(~r/^(Given|When|Then|And|But|\*) (.+)$/, line, capture: :all_but_first)

            {scenarios, current_scenario, current_tags,
             [%Step{keyword: keyword, text: text} | steps]}

          # Ignore other lines
          true ->
            {scenarios, current_scenario, current_tags, steps}
        end
      end)

    # Add the last scenario if present
    if current_scenario do
      [_, scenario_name] = String.split(current_scenario, ":", parts: 2)
      scenario_name = String.trim(scenario_name)

      scenario = %Scenario{
        name: scenario_name,
        steps: Enum.reverse(steps),
        tags: current_tags
      }

      scenarios ++ [scenario]
    else
      scenarios
    end
  end

  # Extract tags from a line like "@tag1 @tag2 @tag3"
  defp extract_tags(line) do
    line
    |> String.split(~r/\s+/)
    |> Enum.filter(&String.starts_with?(&1, "@"))
    |> Enum.map(&String.trim_leading(&1, "@"))
  end

  # Extract tags from lines before a Feature/Scenario, returns {tags, element_line, rest}
  defp extract_tags_and_element(lines, element_prefix) do
    {tag_lines, rest} = Enum.split_while(lines, &(String.starts_with?(&1, "@") or &1 == ""))

    # Extract tags from tag lines
    tags =
      tag_lines
      |> Enum.filter(&String.starts_with?(&1, "@"))
      |> Enum.flat_map(&extract_tags/1)

    # Find the element line
    {element_line, new_rest} =
      case Enum.split_while(rest, &(!String.starts_with?(&1, element_prefix))) do
        {_, []} -> raise "No #{element_prefix} found after tags"
        {_pre, [element | post]} -> {element, post}
      end

    {tags, element_line, new_rest}
  end
end
