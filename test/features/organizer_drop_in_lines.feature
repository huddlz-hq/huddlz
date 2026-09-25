@async @database @conn @organizer_drop_in_lines
Feature: The organizer overview mentions drop-ins
  As an organizer
  I want to know when people who have not joined are coming, and that my huddlz are how people find the group
  So that I expect new faces, without being pushed to chase joins

  Background:
    Given the following users exist:
      | email               | display_name |
      | host612@example.com | Host Hana    |
      | maya612@example.com | Maya Chen    |
      | priya612@example.com | Priya Rao   |
      | dev612@example.com  | Dev Patel    |
      | ana612@example.com  | Ana Silva    |
    And a public group "Tuesday Runners" exists with owner "host612@example.com"

  Scenario: Member growth says how many joiners RSVPd first
    Given an upcoming huddl "Track Tuesday" exists in "Tuesday Runners"
    And "maya612@example.com" has RSVPd to "Track Tuesday"
    And "maya612@example.com" joined "Tuesday Runners" from "the huddl page"
    And "priya612@example.com" joined "Tuesday Runners" from "the group page"
    And I am signed in as "host612@example.com"
    When I visit "/organize/tuesday-runners"
    Then member growth says "1 RSVPd to a huddl first"

  Scenario: Member growth says nothing extra when nobody RSVPd first
    Given "priya612@example.com" joined "Tuesday Runners" from "the group page"
    And I am signed in as "host612@example.com"
    When I visit "/organize/tuesday-runners"
    Then member growth does not mention RSVPing first

  Scenario: Someone who RSVPd as a member, left and joined again did not RSVP first
    Given an upcoming huddl "Track Tuesday" exists in "Tuesday Runners"
    And "maya612@example.com" joined "Tuesday Runners" from "the group page"
    And "maya612@example.com" has RSVPd to "Track Tuesday"
    And "maya612@example.com" leaves "Tuesday Runners"
    And "maya612@example.com" joined "Tuesday Runners" from "the group page"
    And I am signed in as "host612@example.com"
    When I visit "/organize/tuesday-runners"
    Then member growth does not mention RSVPing first

  @cancelled_promotion
  Scenario: A cancelled RSVP from a waitlist promotion still precedes a join
    Given the following capped huddl exists in "Tuesday Runners":
      | title    | description | event_type | starts_at | virtual_link            | max_attendees |
      | Long Run | Weekly run  | virtual    | tomorrow  | https://meet.test/run   | 1             |
    And "maya612@example.com" is on the waitlist for "Long Run"
    And "host612@example.com" cancels their RSVP to "Long Run"
    And "maya612@example.com" cancels their RSVP to "Long Run"
    And "maya612@example.com" joined "Tuesday Runners" from "the group page"
    And I am signed in as "host612@example.com"
    When I visit "/organize/tuesday-runners"
    Then member growth says "1 RSVPd to a huddl first"
    And the feed shows "Maya Chen joined the group" with the note "RSVPd to Long Run first"

  @promotion_after_join
  Scenario: Joining while waitlisted does not count as RSVPing before joining
    Given the following capped huddl exists in "Tuesday Runners":
      | title    | description | event_type | starts_at | virtual_link          | max_attendees |
      | Long Run | Weekly run  | virtual    | tomorrow  | https://meet.test/run | 1             |
    And "maya612@example.com" is on the waitlist for "Long Run"
    And "maya612@example.com" joined "Tuesday Runners" from "the group page"
    And "host612@example.com" cancels their RSVP to "Long Run"
    And I am signed in as "host612@example.com"
    When I visit "/organize/tuesday-runners"
    Then member growth does not mention RSVPing first
    And the feed shows "Maya Chen joined the group" with no note

  Scenario: The next huddl says how many RSVPs aren't members yet
    Given an upcoming huddl "Long Run" exists in "Tuesday Runners"
    And "ana612@example.com" is a member of "Tuesday Runners"
    And "ana612@example.com" has RSVPd to "Long Run"
    And "dev612@example.com" has RSVPd to "Long Run"
    And I am signed in as "host612@example.com"
    When I visit "/organize/tuesday-runners"
    Then the next huddl says "1 of the 3 isn't a member yet"

  Scenario: The next huddl says nothing extra when everyone is a member
    Given an upcoming huddl "Long Run" exists in "Tuesday Runners"
    And "ana612@example.com" is a member of "Tuesday Runners"
    And "ana612@example.com" has RSVPd to "Long Run"
    And I am signed in as "host612@example.com"
    When I visit "/organize/tuesday-runners"
    Then the next huddl does not mention people who aren't members

  Scenario: Recent activity marks an RSVP from someone who hasn't joined
    Given an upcoming huddl "Long Run" exists in "Tuesday Runners"
    And "dev612@example.com" has RSVPd to "Long Run"
    And I am signed in as "host612@example.com"
    When I visit "/organize/tuesday-runners"
    Then the feed shows "Dev Patel RSVPd to Long Run" with the note "Not a member yet"

  Scenario: The mark goes away once they join
    Given an upcoming huddl "Long Run" exists in "Tuesday Runners"
    And "dev612@example.com" has RSVPd to "Long Run"
    And "dev612@example.com" joined "Tuesday Runners" from "the huddl page"
    And I am signed in as "host612@example.com"
    When I visit "/organize/tuesday-runners"
    Then the feed shows "Dev Patel RSVPd to Long Run" with no note

  @former_member_note
  Scenario: A former member's RSVP is marked while they are not a member
    Given an upcoming huddl "Long Run" exists in "Tuesday Runners"
    And "dev612@example.com" joined "Tuesday Runners" from "the group page"
    And "dev612@example.com" leaves "Tuesday Runners"
    And "dev612@example.com" has RSVPd to "Long Run"
    And I am signed in as "host612@example.com"
    When I visit "/organize/tuesday-runners"
    Then the feed shows "Dev Patel RSVPd to Long Run" with the note "Not a member yet"

  Scenario: Recent activity says which huddl a joiner RSVPd to first
    Given an upcoming huddl "Track Tuesday" exists in "Tuesday Runners"
    And "maya612@example.com" has RSVPd to "Track Tuesday"
    And "maya612@example.com" joined "Tuesday Runners" from "the huddl page"
    And I am signed in as "host612@example.com"
    When I visit "/organize/tuesday-runners"
    Then the feed shows "Maya Chen joined the group" with the note "RSVPd to Track Tuesday first"

  Scenario: A member's RSVP gets no mark
    Given an upcoming huddl "Long Run" exists in "Tuesday Runners"
    And "ana612@example.com" is a member of "Tuesday Runners"
    And "ana612@example.com" has RSVPd to "Long Run"
    And I am signed in as "host612@example.com"
    When I visit "/organize/tuesday-runners"
    Then the feed shows "Ana Silva RSVPd to Long Run" with no note

  Scenario: Someone who joined without RSVPing first gets no note
    Given "priya612@example.com" joined "Tuesday Runners" from "the group page"
    And I am signed in as "host612@example.com"
    When I visit "/organize/tuesday-runners"
    Then the feed shows "Priya Rao joined the group" with no note

  Scenario: The API carries the same figures
    Given an upcoming huddl "Track Tuesday" exists in "Tuesday Runners"
    And "maya612@example.com" has RSVPd to "Track Tuesday"
    And "maya612@example.com" joined "Tuesday Runners" from "the huddl page"
    And "dev612@example.com" has RSVPd to "Track Tuesday"
    When "host612@example.com" reads the overview of "Tuesday Runners" for "90d" through GraphQL
    Then the API overview says 1 joiner RSVPd to a huddl first
    And the API overview says 1 RSVP to the next huddl is from someone who isn't a member
    When "host612@example.com" reads the drop-in notes on the activity of "Tuesday Runners" through GraphQL
    Then the API activity says the RSVP from "dev612@example.com" is from someone who isn't a member yet
    And the API activity says the join of "maya612@example.com" followed an RSVP to "Track Tuesday"

  Scenario: Members cannot read them
    Given "ana612@example.com" is a member of "Tuesday Runners"
    When "ana612@example.com" reads the overview of "Tuesday Runners" for "90d" through GraphQL
    Then the API refuses the overview
