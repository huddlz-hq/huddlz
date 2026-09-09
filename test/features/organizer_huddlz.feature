@database @conn
Feature: Organizer huddlz page
  As an organizer
  I want the group's huddlz laid out for managing, with a recurring series shown as one entry
  So that I can see at a glance what is scheduled, how full it is, and edit the right thing

  Background:
    Given the following users exist:
      | email            | display_name | role    |
      | host@example.com | Host User    | regular |
    And a public group "Cyberpunk Builders" exists with owner "host@example.com"
    And I am signed in as "host@example.com"

  Scenario: Upcoming huddlz show their schedule, capacity and an edit action
    Given the huddl "Synthwave Night" exists in group "Cyberpunk Builders" with room for 20 and 5 RSVPs
    And the draft huddl "Modular Jam" exists in group "Cyberpunk Builders"
    When I visit "/organize/cyberpunk-builders/huddlz"
    Then the organizer row for "Synthwave Night" shows when it is and "5 / 20 RSVPs"
    And the organizer row for "Synthwave Night" links to the huddl and offers "Edit"
    And the filter chips read "Upcoming 1", "Drafts 1", "Past 0" and "Cancelled 0"
    And I should not see "Modular Jam"

  Scenario: A recurring series is one entry with its dates
    Given a weekly series "Office hours" exists in group "Cyberpunk Builders" for the next 5 weeks
    When I visit "/organize/cyberpunk-builders/huddlz"
    Then the series "Office hours" is one entry reading "Weekly on" with 5 dates
    And the first date of "Office hours" is marked as next
    And only 3 dates of "Office hours" show until I ask for the rest
    And "Edit series" for "Office hours" opens the edit page on the whole series
