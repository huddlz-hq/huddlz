@database @conn @admin_drop_ins
Feature: The admin overview shows how drop-ins use huddlz
  As the person running huddlz
  I want to see how many RSVPs come from people who have not joined the group, and what they do next
  So that I know whether membership is earning its place and what to build next

  Background:
    Given the following users exist:
      | email                | role  | display_name |
      | admin611@example.com | admin | Admin Alex   |
      | owner611@example.com | user  | Owner Olive  |
      | maya611@example.com  | user  | Maya Chen    |
      | dev611@example.com   | user  | Dev Patel    |
      | jon611@example.com   | user  | Jon Park     |
      | ana611@example.com   | user  | Ana Silva    |
    And a public group "Tuesday Runners" exists with owner "owner611@example.com"

  Scenario: RSVPs from people who weren't members are counted
    Given 3 people RSVPd to a huddl of "Tuesday Runners" without joining the group
    And 5 members of "Tuesday Runners" RSVPd to one of its huddlz
    And I am signed in as "admin611@example.com"
    When I visit "/admin"
    Then the platform "RSVPs" figure shows "8"
    And the Drop-ins panel says "3 of 8 RSVPs came from people who weren't members of the group"
    And the Drop-ins panel says "3 people across 1 group"

  Scenario: Someone who joined before they RSVPd is not a drop-in
    Given "maya611@example.com" joined "Tuesday Runners" and then RSVPd to one of its huddlz
    And I am signed in as "admin611@example.com"
    When I visit "/admin"
    Then the platform "RSVPs" figure shows "1"
    And the Drop-ins panel says "No RSVPs came from people who weren't members of the group in this period."

  Scenario: Someone who RSVPd while a member and has since left is not a drop-in
    Given "maya611@example.com" joined "Tuesday Runners" and then RSVPd to one of its huddlz
    And "maya611@example.com" leaves "Tuesday Runners"
    And I am signed in as "admin611@example.com"
    When I visit "/admin"
    Then the Drop-ins panel says "No RSVPs came from people who weren't members of the group in this period."

  Scenario: What drop-ins did next
    Given "maya611@example.com" dropped in on "Tuesday Runners"
    And "maya611@example.com" joined "Tuesday Runners" from "the group page"
    And "dev611@example.com" dropped in on "Tuesday Runners"
    And "dev611@example.com" RSVPd to another huddl of "Tuesday Runners"
    And "jon611@example.com" dropped in on "Tuesday Runners"
    And I am signed in as "admin611@example.com"
    When I visit "/admin"
    Then the Drop-ins panel says "4 of 4 RSVPs came from people who weren't members of the group"
    And the Drop-ins panel says "3 people across 1 group"
    And the Drop-ins panel shows 1 for "Joined the group"
    And the Drop-ins panel shows 1 for "RSVPd again without joining"
    And the Drop-ins panel shows 1 for "Haven't RSVPd again"

  Scenario: Joining wins over RSVPing again
    Given "maya611@example.com" dropped in on "Tuesday Runners"
    And "maya611@example.com" RSVPd to another huddl of "Tuesday Runners"
    And "maya611@example.com" joined "Tuesday Runners" from "the group page"
    And I am signed in as "admin611@example.com"
    When I visit "/admin"
    Then the Drop-ins panel shows 1 for "Joined the group"
    And the Drop-ins panel shows 0 for "RSVPd again without joining"
    And the Drop-ins panel shows 0 for "Haven't RSVPd again"

  Scenario: Someone who joined and has since left still counts as joined
    Given "maya611@example.com" dropped in on "Tuesday Runners"
    And "maya611@example.com" joined "Tuesday Runners" from "the join suggestion email"
    And "maya611@example.com" leaves "Tuesday Runners"
    And I am signed in as "admin611@example.com"
    When I visit "/admin"
    Then the Drop-ins panel shows 1 for "Joined the group"
    And the Drop-ins panel shows 1 for "The join suggestion email"

  Scenario: Joins are split by where they came from
    Given "maya611@example.com" dropped in on "Tuesday Runners"
    And "maya611@example.com" joined "Tuesday Runners" from "the join suggestion email"
    And "ana611@example.com" dropped in on "Tuesday Runners"
    And "ana611@example.com" joined "Tuesday Runners" from "the huddl page"
    And I am signed in as "admin611@example.com"
    When I visit "/admin"
    Then the Drop-ins panel says "Where the 2 joins came from"
    And the Drop-ins panel shows 1 for "The join suggestion email"
    And the Drop-ins panel shows 1 for "The huddl page"
    And the Drop-ins panel shows 0 for "The group page"

  Scenario: A join with no recorded source
    Given "maya611@example.com" dropped in on "Tuesday Runners"
    And "maya611@example.com" joins "Tuesday Runners" through "GraphQL" without naming a source
    And I am signed in as "admin611@example.com"
    When I visit "/admin"
    Then the Drop-ins panel shows 1 for "No recorded source"

  Scenario: What the suggestion emails led to
    Given an upcoming huddl "Long Run" exists in "Tuesday Runners"
    And "maya611@example.com" has RSVPd to "Long Run"
    And "dev611@example.com" has RSVPd to "Long Run"
    And "jon611@example.com" has RSVPd to "Long Run"
    And "ana611@example.com" has RSVPd to "Long Run"
    And "Long Run" completes
    And a day passes
    And "maya611@example.com" joined "Tuesday Runners" from "the join suggestion email"
    And "dev611@example.com" chose not now for "Tuesday Runners"
    And "jon611@example.com" turned off suggestions to join groups they've dropped in on
    And I am signed in as "admin611@example.com"
    When I visit "/admin"
    Then the Drop-ins panel says "4 suggestions to join were emailed"
    And the Drop-ins panel shows 1 for "Joined since"
    And the Drop-ins panel shows 1 for "Chose Not now"
    And the Drop-ins panel shows 1 for "Turned the email off"
    And the Drop-ins panel shows 1 for "Nothing yet"

  Scenario: The panel follows the period
    Given "maya611@example.com" dropped in on "Tuesday Runners" 60 days ago
    And I am signed in as "admin611@example.com"
    When I visit "/admin?period=30d"
    Then the Drop-ins panel says "No RSVPs came from people who weren't members of the group in this period."
    When I visit "/admin?period=90d"
    Then the Drop-ins panel says "1 of 1 RSVP came from a person who wasn't a member of the group"
    And the Drop-ins panel says "1 person across 1 group"

  Scenario: A period that starts before the data does
    Given "maya611@example.com" dropped in on "Tuesday Runners" 10 days ago
    And I am signed in as "admin611@example.com"
    When I visit "/admin?period=90d"
    Then the Drop-ins panel says it has been measured since 10 days ago

  Scenario: A period the data covers says nothing about measuring
    Given "maya611@example.com" dropped in on "Tuesday Runners" 60 days ago
    And I am signed in as "admin611@example.com"
    When I visit "/admin?period=30d"
    Then the Drop-ins panel does not say when it has been measured since

  Scenario: Nothing to show
    Given 2 members of "Tuesday Runners" RSVPd to one of its huddlz
    And I am signed in as "admin611@example.com"
    When I visit "/admin"
    Then the Drop-ins panel says "No RSVPs came from people who weren't members of the group in this period."
    And the Drop-ins panel draws no bars

  Scenario: The figures come with the platform overview action
    Given 3 people RSVPd to a huddl of "Tuesday Runners" without joining the group
    When "admin611@example.com" runs the platform overview action
    Then its drop-in figures count 3 of 3 RSVPs

  Scenario: Only admins can read the figures
    When "owner611@example.com" runs the platform overview action
    Then the platform overview action is refused
