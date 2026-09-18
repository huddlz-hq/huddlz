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
