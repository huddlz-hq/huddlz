@async @database @participation_history
Feature: Participation history
  As huddlz
  I want the record of who joined, RSVPed and organized alongside troubleshooting history for two years
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

  Scenario: A huddl's original and edited details stay with its creation and turnout
    Given "Kickoff" was created, edited and had its turnout recorded four months ago
    When the daily pruning runs
    Then the creation of "Kickoff" and its turnout recording are still on record
    And the original and edited descriptions of "Kickoff" are still on record

  Scenario: Cancelling an RSVP keeps the RSVP on record
    Given "maya565@example.com" RSVPed to "Kickoff"
    When "maya565@example.com" cancels the RSVP to "Kickoff"
    Then the RSVP and the cancellation by "maya565@example.com" are both on record

  Scenario: An organizer removing a member is the organizer's action
    Given "maya565@example.com" is a member of "Portland Elixir"
    When the owner removes "maya565@example.com" from "Portland Elixir"
    Then the removal names "owner565@example.com" as the actor and "maya565@example.com" as the person removed

  Scenario: A group's edited description is still on record a year later
    Given "Portland Elixir" had its description changed 365 days ago
    When the daily pruning runs
    Then the edited description of "Portland Elixir" is still on record

  Scenario: A group's edited description ages out after two years
    Given "Portland Elixir" had its description changed 731 days ago
    When the daily pruning runs
    Then the edited description of "Portland Elixir" is no longer on record
