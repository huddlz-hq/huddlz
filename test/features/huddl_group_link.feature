@database @conn
Feature: Reaching a huddl's group from its page
  A huddl page names the group hosting it, so a visitor can learn about the
  group and get to it in one step.

  Scenario: A visitor follows the hosting group from a huddl
    Given a public group "Phoenix Elixir Meetup" in "Saint Augustine, FL" with 3 other members
    And an upcoming huddl "LiveView streams in practice" hosted by that group
    When I read the huddl page for "LiveView streams in practice"
    Then the huddl says it is hosted by "Phoenix Elixir Meetup" with "4 members"
    When I follow the hosting group link
    Then I am on the group page for "Phoenix Elixir Meetup"
