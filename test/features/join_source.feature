@async @database @conn @join_source
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

  Scenario: Joining from the groups page
    Given "maya610@example.com" has RSVPd to "Long Run"
    And I am signed in as "maya610@example.com"
    When I visit "/groups"
    And I join "Tuesday Runners" from the groups I've dropped in on
    Then the join of "maya610@example.com" to "Tuesday Runners" is recorded as coming from "the groups page"

  Scenario: Joining from the group page
    Given I am signed in as "maya610@example.com"
    When I visit the group page for "Tuesday Runners"
    And I click the "Join Group" button
    Then the join of "maya610@example.com" to "Tuesday Runners" is recorded as coming from "the group page"

  Scenario: An unknown tag counts as the group page
    Given I am signed in as "maya610@example.com"
    When I visit the "Tuesday Runners" group page tagged "somewhere_else"
    And I click the "Join Group" button
    Then the join of "maya610@example.com" to "Tuesday Runners" is recorded as coming from "the group page"

  Scenario: An unknown tag replaces a previously recognised source
    Given I am signed in as "maya610@example.com"
    When I visit the "Tuesday Runners" group page tagged "join_suggestion_email"
    And I visit the "Tuesday Runners" group page tagged "somewhere_else"
    And I click the "Join Group" button
    Then the join of "maya610@example.com" to "Tuesday Runners" is recorded as coming from "the group page"

  Scenario: Joining after following the join suggestion email
    Given "maya610@example.com" has RSVPd to "Long Run"
    And "Long Run" completes
    And a day passes
    And "maya610@example.com" receives an email suggesting they join "Tuesday Runners"
    And I am signed in as "maya610@example.com"
    When I follow the email's link to the group page
    And I click the "Join Group" button
    Then the join of "maya610@example.com" to "Tuesday Runners" is recorded as coming from "the join suggestion email"

  Scenario: The tag does not stay in the group page's address
    Given "maya610@example.com" has RSVPd to "Long Run"
    And "Long Run" completes
    And a day passes
    And "maya610@example.com" receives an email suggesting they join "Tuesday Runners"
    And I am signed in as "maya610@example.com"
    When I follow the email's link to the group page
    Then the address of the "Tuesday Runners" group page carries no tag

  Scenario: Loading the group page again during the visit keeps the source
    Given "maya610@example.com" has RSVPd to "Long Run"
    And "Long Run" completes
    And a day passes
    And "maya610@example.com" receives an email suggesting they join "Tuesday Runners"
    And I am signed in as "maya610@example.com"
    When I follow the email's link to the group page
    And I load the "Tuesday Runners" group page again
    And I click the "Join Group" button
    Then the join of "maya610@example.com" to "Tuesday Runners" is recorded as coming from "the join suggestion email"

  Scenario: Joining after following the suggestion in my notifications
    Given "maya610@example.com" has RSVPd to "Long Run"
    And "Long Run" completes
    And a day passes
    And I am signed in as "maya610@example.com"
    When I visit "/notifications"
    And the suggestion leads to the "Tuesday Runners" group page
    And I click the "Join Group" button
    Then the join of "maya610@example.com" to "Tuesday Runners" is recorded as coming from "the join suggestion notification"

  Scenario: Joining after following the RSVP confirmation email
    Given "maya610@example.com" has RSVPd to "Long Run"
    And I am signed in as "maya610@example.com"
    When I follow the RSVP confirmation email's link to the group page
    And I click the "Join Group" button
    Then the join of "maya610@example.com" to "Tuesday Runners" is recorded as coming from "the RSVP confirmation email"

  Scenario: Signing in on the way keeps the source
    Given the user "maya610@example.com" has password "Password123!"
    And "maya610@example.com" has RSVPd to "Long Run"
    And "Long Run" completes
    And a day passes
    And "maya610@example.com" receives an email suggesting they join "Tuesday Runners"
    When I follow the email's link to the group page
    And I sign in to join as "maya610@example.com" with password "Password123!"
    And I click the "Join Group" button
    Then the join of "maya610@example.com" to "Tuesday Runners" is recorded as coming from "the join suggestion email"

  Scenario Outline: Joining through the API naming a source
    When "maya610@example.com" joins "Tuesday Runners" through "<api>" naming the source "huddl_page"
    Then the join of "maya610@example.com" to "Tuesday Runners" is recorded as coming from "the huddl page"

    Examples:
      | api      |
      | GraphQL  |
      | JSON:API |

  Scenario Outline: Joining through the API without a source
    When "maya610@example.com" joins "Tuesday Runners" through "<api>" without naming a source
    Then "maya610@example.com" belongs to "Tuesday Runners"
    And the join of "maya610@example.com" to "Tuesday Runners" has no recorded source

    Examples:
      | api      |
      | GraphQL  |
      | JSON:API |

  Scenario Outline: The API refuses a source it does not know
    When "maya610@example.com" joins "Tuesday Runners" through "<api>" naming the source "a_billboard"
    Then the join is refused
    And "maya610@example.com" does not belong to "Tuesday Runners"

    Examples:
      | api      |
      | GraphQL  |
      | JSON:API |

  Scenario: The source outlives the membership
    Given "maya610@example.com" joined "Tuesday Runners" from "the join suggestion email"
    When "maya610@example.com" leaves "Tuesday Runners"
    Then "maya610@example.com" does not belong to "Tuesday Runners"
    And the activity log of "Tuesday Runners" still says the join of "maya610@example.com" came from "the join suggestion email"
