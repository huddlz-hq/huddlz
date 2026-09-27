@async @database @conn
Feature: Organizer huddlz page
  As an organizer
  I want the group's huddlz laid out for managing, in date order, with series dates marked
  So that I can see at a glance what is scheduled, how full it is, and edit the right thing

  Background:
    Given the following users exist:
      | email                             | display_name | role    |
      | host+organizer-huddlz@example.com | Host User    | regular |
    And a public group "Organizer Huddlz Cyberpunk Builders" exists with owner "host+organizer-huddlz@example.com"
    And I am signed in as "host+organizer-huddlz@example.com"

  Scenario: Upcoming huddlz show their schedule, capacity and an edit action
    Given the huddl "Synthwave Night" exists in group "Organizer Huddlz Cyberpunk Builders" with room for 20 and 5 RSVPs
    And the draft huddl "Modular Jam" exists in group "Organizer Huddlz Cyberpunk Builders"
    When I visit "/organize/organizer-huddlz-cyberpunk-builders/huddlz"
    Then the organizer row for "Synthwave Night" shows when it is and "5 / 20 RSVPs"
    And the organizer row for "Synthwave Night" links to the huddl and offers "Edit"
    And the filter chips read "Upcoming 1", "Drafts 1", "Past 0" and "Cancelled 0"
    And I should not see "Modular Jam"

  Scenario: A weekly series includes its fifth date when recurrence ends on that date
    Given a weekly series "Office hours" exists in group "Organizer Huddlz Cyberpunk Builders" for the next 5 weeks
    And the huddl "Synthwave Night" exists in group "Organizer Huddlz Cyberpunk Builders" with room for 20 and 5 RSVPs
    When I visit "/organize/organizer-huddlz-cyberpunk-builders/huddlz"
    Then the huddlz are listed day by day in date order
    And every date of "Office hours" is marked "Weekly"
    And the organizer dates of "Office hours" show the selected series end date
    And "Edit series" on a date of "Office hours" opens the edit page on the whole series
    And the series edit form shows the selected end date
