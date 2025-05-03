defmodule Gherkin.ParserTest do
  use ExUnit.Case, async: true

  alias Gherkin.{Feature, Background, Scenario, Step}

  describe "parse/1" do
    test "parses a minimal feature file with one scenario and background" do
      gherkin = """
      Feature: User signs up for event

      Background:
        Given a logged in user

      Scenario: User joins an event
        Given an event titled \"Tech Gathering\"
        When I visit \"/\"
        Then I should see the event
        When I click \"join\" on the first event
        Then I should see \"joined event\"
      """

      expected = %Feature{
        name: "User signs up for event",
        description: "",
        background: %Background{
          steps: [
            %Step{keyword: "Given", text: "a logged in user"}
          ]
        },
        scenarios: [
          %Scenario{
            name: "User joins an event",
            steps: [
              %Step{keyword: "Given", text: "an event titled \"Tech Gathering\""},
              %Step{keyword: "When", text: "I visit \"/\""},
              %Step{keyword: "Then", text: "I should see the event"},
              %Step{keyword: "When", text: "I click \"join\" on the first event"},
              %Step{keyword: "Then", text: "I should see \"joined event\""}
            ]
          }
        ]
      }

      assert Gherkin.Parser.parse(gherkin) == expected
    end
  end
end
