@database @conn @drop_in_groups_page
Feature: Groups I've dropped in on appear on my groups page
  As someone who has RSVPd to huddlz of groups I have not joined
  I want those groups listed on my groups page
  So that joining one later is easy, and saying "Not now" is final

  Background:
    Given the following users exist:
      | email                | display_name |
      | owner605@example.com | Owner Olive  |
      | maya605@example.com  | Maya Chen    |
    And a public group "Tuesday Runners" exists with owner "owner605@example.com"
    And I am signed in as "maya605@example.com"

  Scenario: An upcoming RSVP lists the group
    Given an upcoming huddl "Long Run" exists in "Tuesday Runners"
    And "maya605@example.com" has RSVPd to "Long Run"
    When I visit "/groups"
    Then "Tuesday Runners" is listed among groups I've dropped in on
    And its listing says I'm going to "Long Run"

  Scenario: A completed huddl lists the group
    Given "maya605@example.com" held an RSVP to "Track Night" in "Tuesday Runners" when it completed
    When I visit "/groups"
    Then "Tuesday Runners" is listed among groups I've dropped in on
    And its listing says I RSVPd to "Track Night"

  Scenario: A waitlist spot lists the group
    Given an upcoming huddl "Long Run" exists in "Tuesday Runners"
    And "Long Run" has room for 1 people
    And "maya605@example.com" is on the waitlist for "Long Run"
    When I visit "/groups"
    Then "Tuesday Runners" is listed among groups I've dropped in on
    And its listing says I'm waitlisted for "Long Run"

  Scenario: An upcoming huddl is mentioned ahead of a completed one
    Given "maya605@example.com" held an RSVP to "Track Night" in "Tuesday Runners" when it completed
    And an upcoming huddl "Long Run" exists in "Tuesday Runners"
    And "maya605@example.com" has RSVPd to "Long Run"
    When I visit "/groups"
    Then its listing says I'm going to "Long Run"

  Scenario: Joining from the list
    Given an upcoming huddl "Long Run" exists in "Tuesday Runners"
    And "maya605@example.com" has RSVPd to "Long Run"
    When I visit "/groups"
    And I join "Tuesday Runners" from the groups I've dropped in on
    Then "Tuesday Runners" is listed among my groups
    And there is no section for groups I've dropped in on

  Scenario: Not now removes the group for good
    Given an upcoming huddl "Long Run" exists in "Tuesday Runners"
    And an upcoming huddl "Hill Repeats" exists in "Tuesday Runners"
    And "maya605@example.com" has RSVPd to "Long Run"
    When I visit "/groups"
    And I choose not now for "Tuesday Runners"
    Then there is no section for groups I've dropped in on
    When "maya605@example.com" has RSVPd to "Hill Repeats"
    And I visit "/groups"
    Then there is no section for groups I've dropped in on

  Scenario: The section is absent when there is nothing to show
    Given "maya605@example.com" is a member of "Tuesday Runners"
    And an upcoming huddl "Long Run" exists in "Tuesday Runners"
    And "maya605@example.com" has RSVPd to "Long Run"
    When I visit "/groups"
    Then there is no section for groups I've dropped in on

  Scenario: The section only appears with all my groups
    Given an upcoming huddl "Long Run" exists in "Tuesday Runners"
    And "maya605@example.com" has RSVPd to "Long Run"
    When I visit "/groups?filter=joined"
    Then there is no section for groups I've dropped in on

  Scenario: More than six groups
    Given "maya605@example.com" has dropped in on 8 public groups
    When I visit "/groups"
    Then 6 groups are listed among groups I've dropped in on
    When I click the "Show all 8" button
    Then 8 groups are listed among groups I've dropped in on
