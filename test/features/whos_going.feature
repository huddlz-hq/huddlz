@database @conn @whos_going
Feature: Who's going
  As someone going to a huddl
  I want to see who else is going
  So that I know who to expect, while nobody else can see that I'm going

  Background:
    Given the following users exist:
      | email               | display_name |
      | owner14@example.com | Owner Olive  |
      | maya14@example.com  | Maya Chen    |
      | sam14@example.com   | Sam Rivera   |
      | quinn14@example.com | Quinn Park   |
    And a public group "Portland Elixir" exists with owner "owner14@example.com"
    And an upcoming huddl "Elixir hack night" exists in "Portland Elixir"
    And "maya14@example.com" and "sam14@example.com" have RSVPd to "Elixir hack night"

  Scenario: Someone going sees who else is going
    Given I am signed in as "maya14@example.com"
    When I visit the huddl "Elixir hack night"
    Then the people going are "You, Owner Olive, Sam Rivera"

  Scenario: Someone who has not RSVPd sees only the count
    Given I am signed in as "quinn14@example.com"
    When I visit the huddl "Elixir hack night"
    Then I should see "3 people attending"
    And nobody going is named
    And I should see "RSVP to see who's going."

  Scenario: A visitor sees only the count
    When I visit the huddl "Elixir hack night"
    Then I should see "3 people attending"
    And nobody going is named
    And I should see "Sign in and RSVP to see who's going."

  Scenario: The group's owner gets no exception on the huddl page
    Given "owner14@example.com" cancels their RSVP to "Elixir hack night"
    And I am signed in as "owner14@example.com"
    When I visit the huddl "Elixir hack night"
    Then nobody going is named
    And I should see "RSVP to see who's going."

  Scenario: RSVPing reveals the list and cancelling hides it
    Given I am signed in as "quinn14@example.com"
    When I visit the huddl "Elixir hack night"
    And I click the "RSVP to this huddl" button
    Then the people going are "You, Owner Olive, Maya Chen, Sam Rivera"
    When I click the "Cancel RSVP" button
    Then nobody going is named

  Scenario: Someone on the waitlist sees who's going
    Given "Elixir hack night" has room for 3 people
    And I am signed in as "quinn14@example.com"
    When I visit the huddl "Elixir hack night"
    Then I should see "Join the waitlist to see who's going."
    When I click the "Join waitlist" button
    Then the people going are "Owner Olive, Maya Chen, Sam Rivera"

  Scenario: Someone else RSVPing appears without a reload
    Given I am signed in as "maya14@example.com"
    And I visit the huddl "Elixir hack night"
    When "quinn14@example.com" RSVPs to "Elixir hack night" in another session
    Then the people going are "You, Owner Olive, Sam Rivera, Quinn Park"

  Scenario: A long list folds to six names
    Given 10 more people have RSVPd to "Elixir hack night"
    And I am signed in as "maya14@example.com"
    When I visit the huddl "Elixir hack night"
    Then 6 people going are named
    When I click the "Show all 13" button
    Then 13 people going are named
    And I should see "Show fewer"

  Scenario: Nobody has RSVPd yet
    Given an upcoming huddl "Lightning talks" exists in "Portland Elixir"
    And "owner14@example.com" cancels their RSVP to "Lightning talks"
    And I am signed in as "quinn14@example.com"
    When I visit the huddl "Lightning talks"
    Then I should see "No one yet."
    And I should not see "RSVP to see who's going."

  Scenario: An ended huddl shows who RSVPd, not who came
    Given a past huddl "Elixir retro" exists in "Portland Elixir"
    And "maya14@example.com" and "sam14@example.com" have RSVPd to "Elixir retro"
    And I am signed in as "maya14@example.com"
    When I visit the huddl "Elixir retro"
    Then I should see "2 people RSVPd"
    And I should not see "attended"
    And the people going are "You, Sam Rivera"

  Scenario Outline: The API names people going only to people who are going
    When "maya14@example.com" reads who is going to "Elixir hack night" through "<api>"
    Then the API names "Sam Rivera" among the people going
    When "quinn14@example.com" reads who is going to "Elixir hack night" through "<api>"
    Then the API names nobody

    Examples:
      | api      |
      | JSON:API |
      | GraphQL  |
