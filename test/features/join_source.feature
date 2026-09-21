@database @conn @join_source
Feature: A join records where it came from
  As the person running huddlz
  I want each join to say which page or email led to it
  So that I can tell which ways of joining a group people actually use

  Background:
    Given the following users exist:
      | email                | display_name |
      | owner610@example.com | Owner Olive  |
      | maya610@example.com  | Maya Chen    |
    And a public group "Tuesday Runners" exists with owner "owner610@example.com"
    And an upcoming huddl "Long Run" exists in "Tuesday Runners"

  Scenario: Joining from the huddl page
    Given "maya610@example.com" has RSVPd to "Long Run"
    And I am signed in as "maya610@example.com"
    When I visit the huddl "Long Run"
    And I join "Tuesday Runners" from the suggestion
    Then the join of "maya610@example.com" to "Tuesday Runners" is recorded as coming from "the huddl page"
