@async @database @conn
Feature: Waitlist
  As a user trying to attend a full huddl
  I want to join a waitlist
  So that I can attend if a spot opens up

  Background:
    Given the following users exist:
      | email                    | display_name | role     |
      | organizer@example.com    | Organizer    | verified |
      | member@example.com       | Member       | verified |
      | hopeful@example.com      | Hopeful      | verified |
    And the following group exists:
      | name          | description        | is_public | owner_email           |
      | Tech Meetup   | Local tech group   | true      | organizer@example.com |
    And "member@example.com" is a member of "Tech Meetup"
    And "hopeful@example.com" is a member of "Tech Meetup"
    And the following capped huddl exists in "Tech Meetup":
      | title              | description       | event_type | starts_at    | virtual_link                | max_attendees |
      | Capped Code Review | Limited seats     | virtual    | tomorrow 2pm | https://zoom.us/j/123456789 | 1             |
    And "member@example.com" has RSVPed to "Capped Code Review"

  Scenario: User joins the waitlist when the huddl is full
    Given I am logged in as "hopeful@example.com"
    When I visit the "Capped Code Review" huddl page
    Then I should see "Event Full"
    And I should see "Join Waitlist"

    When I click "Event Full — Join Waitlist"
    Then I should see "Added to the waitlist"
    And I should see "On waitlist"
    And I should see "Leave Waitlist"

  Scenario: User leaves the waitlist
    Given I am logged in as "hopeful@example.com"
    And I have joined the waitlist for "Capped Code Review"
    When I visit the "Capped Code Review" huddl page
    Then I should see "On waitlist"

    When I click "Leave Waitlist"
    Then I should see "Removed from the waitlist"
    And I should see "Join Waitlist"
    And I should not see "On waitlist"

  Scenario: User is promoted when an attendee cancels
    Given I am logged in as "hopeful@example.com"
    And I have joined the waitlist for "Capped Code Review"
    When "member@example.com" cancels their RSVP to "Capped Code Review"
    And I visit the "Capped Code Review" huddl page
    Then I should see "You're attending!"
    And I should not see "On waitlist"
