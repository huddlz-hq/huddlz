@database @conn @drop_in_emails
Feature: Drop-ins are told once by email that they can join the group
  As someone who RSVPd to a huddl of a group I have not joined
  I want to hear once that the group exists and how to follow it
  So that I can join if I liked it, and am never nagged if I did not

  Background:
    Given the following users exist:
      | email                | display_name |
      | owner606@example.com | Owner Olive  |
      | maya606@example.com  | Maya Chen    |
    And a public group "Tuesday Runners" exists with owner "owner606@example.com"
    And an upcoming huddl "Long Run" exists in "Tuesday Runners"

  Scenario: The RSVP confirmation email mentions the group to a drop-in
    When "maya606@example.com" has RSVPd to "Long Run"
    Then the RSVP confirmation email to "maya606@example.com" says "Tuesday Runners" hosts it and that joining is how to hear about its next huddlz

  Scenario: The RSVP confirmation email says nothing extra to a member
    Given "maya606@example.com" is a member of "Tuesday Runners"
    When "maya606@example.com" has RSVPd to "Long Run"
    Then the RSVP confirmation email to "maya606@example.com" does not suggest joining the group

  Scenario: A drop-in is emailed a day after the huddl completes
    Given an upcoming huddl "Track Night" exists in "Tuesday Runners"
    And "maya606@example.com" has RSVPd to "Long Run"
    When "Long Run" completes
    And a day passes
    Then "maya606@example.com" receives an email suggesting they join "Tuesday Runners"
    And it says they RSVPd to "Long Run"
    And it lists "Track Night" as coming up
    And it says this is the only time huddlz will suggest it

  Scenario: The suggestion is in the person's notifications and leads to the group
    Given "maya606@example.com" has RSVPd to "Long Run"
    And "Long Run" completes
    And a day passes
    And I am signed in as "maya606@example.com"
    When I visit "/notifications"
    Then my notifications suggest joining "Tuesday Runners"
    And the suggestion leads to the "Tuesday Runners" group page

  Scenario: No email goes out before a day has passed
    Given "maya606@example.com" has RSVPd to "Long Run"
    When "Long Run" completes
    Then "maya606@example.com" receives no email about joining "Tuesday Runners"

  Scenario: The suggestion email says when nothing is scheduled
    Given "maya606@example.com" has RSVPd to "Long Run"
    When "Long Run" completes
    And a day passes
    Then "maya606@example.com" receives an email suggesting they join "Tuesday Runners"
    And it says nothing is on the group's calendar yet

  Scenario: Only one suggestion email per group
    Given "maya606@example.com" was emailed the suggestion to join "Tuesday Runners" after "Long Run"
    And an upcoming huddl "Track Night" exists in "Tuesday Runners"
    And "maya606@example.com" has RSVPd to "Track Night"
    When "Track Night" completes
    And a day passes
    Then "maya606@example.com" receives no email about joining "Tuesday Runners"

  Scenario: A waitlist spot does not trigger the email
    Given "Long Run" has room for 1 people
    And "maya606@example.com" is on the waitlist for "Long Run"
    When "Long Run" completes
    And a day passes
    Then "maya606@example.com" receives no email about joining "Tuesday Runners"

  Scenario: A cancelled huddl does not trigger the email
    Given "maya606@example.com" has RSVPd to "Long Run"
    When "Long Run" is cancelled by its organizer
    And a day passes
    Then "maya606@example.com" receives no email about joining "Tuesday Runners"

  Scenario: Joining during the wait cancels the email
    Given "maya606@example.com" has RSVPd to "Long Run"
    When "Long Run" completes
    And "maya606@example.com" is a member of "Tuesday Runners"
    And a day passes
    Then "maya606@example.com" receives no email about joining "Tuesday Runners"

  Scenario: Not now cancels the email
    Given "maya606@example.com" has RSVPd to "Long Run"
    And "maya606@example.com" chose not now for "Tuesday Runners"
    When "Long Run" completes
    And a day passes
    Then "maya606@example.com" receives no email about joining "Tuesday Runners"

  Scenario: Someone who left the group is not emailed
    Given "maya606@example.com" joined and then left "Tuesday Runners"
    And "maya606@example.com" has RSVPd to "Long Run"
    When "Long Run" completes
    And a day passes
    Then "maya606@example.com" receives no email about joining "Tuesday Runners"

  Scenario: Someone who was removed from the group is not emailed
    Given "maya606@example.com" joined "Tuesday Runners" and was removed by "owner606@example.com"
    And "maya606@example.com" has RSVPd to "Long Run"
    When "Long Run" completes
    And a day passes
    Then "maya606@example.com" receives no email about joining "Tuesday Runners"

  Scenario: The email can be turned off, and the suggestion still reaches notifications
    Given "maya606@example.com" turned off suggestions to join groups they've dropped in on
    And "maya606@example.com" has RSVPd to "Long Run"
    And "Long Run" completes
    And a day passes
    Then "maya606@example.com" receives no email about joining "Tuesday Runners"
    And I am signed in as "maya606@example.com"
    And I visit "/notifications"
    And my notifications suggest joining "Tuesday Runners"

  Scenario: The suggestion can be switched off from the notifications page
    Given I am signed in as "maya606@example.com"
    When I visit "/profile/notifications"
    Then I should see "Suggestion to join a group I've dropped in on"
