@database @conn @drop_in
Feature: Drop-ins can join the group from the huddl page
  As someone going to a huddl of a group I have not joined
  I want to be told once that I can join the group
  So that I hear about its next huddlz without joining being forced on me

  Background:
    Given the following users exist:
      | email                | display_name |
      | owner604@example.com | Owner Olive  |
      | maya604@example.com  | Maya Chen    |
    And a public group "Portland Elixir" exists with owner "owner604@example.com"
    And an upcoming huddl "Elixir hack night" exists in "Portland Elixir"

  Scenario: A signed-in non-member can join the group from the huddl page
    Given I am signed in as "maya604@example.com"
    When I visit the huddl "Elixir hack night"
    Then I can join "Portland Elixir" from the huddl page
    When I join "Portland Elixir" from the huddl page
    Then I am shown as a member of "Portland Elixir" on the huddl page
    And "maya604@example.com" belongs to "Portland Elixir"

  Scenario: RSVPing does not join the group
    Given I am signed in as "maya604@example.com"
    When I visit the huddl "Elixir hack night"
    And I click the "RSVP to this huddl" button
    Then "maya604@example.com" does not belong to "Portland Elixir"
    And the huddl page suggests joining "Portland Elixir"

  Scenario: Joining from the suggestion
    Given I am signed in as "maya604@example.com"
    And "maya604@example.com" has RSVPd to "Elixir hack night"
    When I visit the huddl "Elixir hack night"
    And I join "Portland Elixir" from the suggestion
    Then the huddl page does not suggest joining "Portland Elixir"
    And I am shown as a member of "Portland Elixir" on the huddl page
    And "maya604@example.com" belongs to "Portland Elixir"

  Scenario: Joining the waitlist also brings the suggestion
    Given "Elixir hack night" has room for 1 people
    And I am signed in as "maya604@example.com"
    When I visit the huddl "Elixir hack night"
    And I click the "Join waitlist" button
    Then the huddl page suggests joining "Portland Elixir"

  Scenario: Members are not reminded
    Given "maya604@example.com" is a member of "Portland Elixir"
    And I am signed in as "maya604@example.com"
    When I visit the huddl "Elixir hack night"
    And I click the "RSVP to this huddl" button
    Then the huddl page does not suggest joining "Portland Elixir"

  Scenario: Someone who has not RSVPd is not reminded
    Given I am signed in as "maya604@example.com"
    When I visit the huddl "Elixir hack night"
    Then the huddl page does not suggest joining "Portland Elixir"

  Scenario: Not now ends the suggestion for that group
    Given an upcoming huddl "Elixir lightning talks" exists in "Portland Elixir"
    And I am signed in as "maya604@example.com"
    And "maya604@example.com" has RSVPd to "Elixir hack night"
    When I visit the huddl "Elixir hack night"
    And I decline the suggestion to join "Portland Elixir"
    Then the huddl page does not suggest joining "Portland Elixir"
    And I can join "Portland Elixir" from the huddl page
    When I visit the huddl "Elixir lightning talks"
    And I click the "RSVP to this huddl" button
    Then the huddl page does not suggest joining "Portland Elixir"

  Scenario: Someone who left the group is not reminded
    Given "maya604@example.com" joined and then left "Portland Elixir"
    And I am signed in as "maya604@example.com"
    When I visit the huddl "Elixir hack night"
    And I click the "RSVP to this huddl" button
    Then the huddl page does not suggest joining "Portland Elixir"
    And I can join "Portland Elixir" from the huddl page

  Scenario: Someone removed from the group is not reminded
    Given "maya604@example.com" joined "Portland Elixir" and was removed by "owner604@example.com"
    And I am signed in as "maya604@example.com"
    When I visit the huddl "Elixir hack night"
    And I click the "RSVP to this huddl" button
    Then the huddl page does not suggest joining "Portland Elixir"

  Scenario Outline: Groups I've dropped in on are available on the API
    Given "maya604@example.com" has RSVPd to "Elixir hack night"
    When "maya604@example.com" lists the groups they've dropped in on through "<api>"
    Then the API returns the group "Portland Elixir"
    When "maya604@example.com" declines the suggestion to join "Portland Elixir" through "<api>"
    And "maya604@example.com" lists the groups they've dropped in on through "<api>"
    Then the API returns no groups

    Examples:
      | api      |
      | GraphQL  |
      | JSON:API |

  Scenario: Groups I belong to, or only browsed, are not drop-in groups
    Given a public group "Founder Coffee" exists with owner "owner604@example.com"
    And an upcoming huddl "Morning coffee" exists in "Founder Coffee"
    And "maya604@example.com" is a member of "Portland Elixir"
    And "maya604@example.com" has RSVPd to "Elixir hack night"
    When "maya604@example.com" lists the groups they've dropped in on through "GraphQL"
    Then the API returns no groups
