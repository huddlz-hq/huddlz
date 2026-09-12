@database @participation_history
Feature: Participation history
  As huddlz
  I want the record of who joined, RSVPed and organized to outlive troubleshooting history
  So that participation over a year can be charted later without guessing

  Background:
    Given the following users exist:
      | email                 | role | display_name |
      | owner565@example.com  | user | Owner Olive  |
      | maya565@example.com   | user | Member Maya  |
    And a public group "Portland Elixir" exists with owner "owner565@example.com"
    And the in-person huddl "Kickoff" in "Portland Elixir" is upcoming with 0 RSVPs

  Scenario: An RSVP from a year ago is still on record after the daily pruning
    Given "maya565@example.com" RSVPed to "Kickoff" a year ago
    When the daily pruning runs
    Then the RSVP by "maya565@example.com" to "Kickoff" is still on record

  Scenario: A join from more than two years ago has aged out
    Given "maya565@example.com" joined "Portland Elixir" two years and a day ago
    When the daily pruning runs
    Then the join by "maya565@example.com" to "Portland Elixir" is no longer on record

  Scenario: A huddl's edits age out while its creation and turnout stay
    Given "Kickoff" was created, edited and had its turnout recorded four months ago
    When the daily pruning runs
    Then the creation of "Kickoff" and its turnout recording are still on record
    And the edit to "Kickoff" is no longer on record

  Scenario: Cancelling an RSVP keeps the RSVP on record
    Given "maya565@example.com" RSVPed to "Kickoff"
    When "maya565@example.com" cancels the RSVP to "Kickoff"
    Then the RSVP and the cancellation by "maya565@example.com" are both on record

  Scenario: An organizer removing a member is the organizer's action
    Given "maya565@example.com" is a member of "Portland Elixir"
    When the owner removes "maya565@example.com" from "Portland Elixir"
    Then the removal names "owner565@example.com" as the actor and "maya565@example.com" as the person removed
