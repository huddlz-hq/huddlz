Feature: RSVP Cancellation
  As a user who has RSVPed to a huddl
  I want to be able to cancel my RSVP
  So that I can update my attendance status if my plans change

  Background:
    Given the following users exist:
      | email                    | display_name | role     |
      | organizer@example.com    | Organizer    | verified |
      | member@example.com       | Member       | verified |
    And the following group exists:
      | name          | description        | is_public | owner_email           |
      | Tech Meetup   | Local tech group   | true      | organizer@example.com |
    And "member@example.com" is a member of "Tech Meetup"
    And the following huddl exists in "Tech Meetup":
      | title                 | description              | event_type | starts_at    | virtual_link                |
      | Virtual Code Review   | Let's review some code   | virtual    | tomorrow 2pm | https://zoom.us/j/123456789 |

  Scenario: User cancels their RSVP to a huddl
    Given I am logged in as "member@example.com"
    And I am on the "Tech Meetup" group page
    When I click on "Virtual Code Review"
    Then I should see "Virtual Code Review"
    And I should see "Let's review some code"
    And I should see "RSVP to this huddl"
    
    When I click "RSVP to this huddl"
    Then I should see "Successfully RSVPed to this huddl!"
    And I should see "You're attending!"
    And I should see "Cancel RSVP"
    And I should see "1 person attending"
    
    When I click "Cancel RSVP"
    Then I should see "RSVP cancelled successfully"
    And I should see "RSVP to this huddl"
    And I should not see "You're attending!"
    And I should see "Be the first to RSVP!"

  Scenario: User can RSVP again after cancelling
    Given I am logged in as "member@example.com"
    And I have RSVPed to "Virtual Code Review"
    When I visit the "Virtual Code Review" huddl page
    And I click "Cancel RSVP"
    Then I should see "RSVP cancelled successfully"
    
    When I click "RSVP to this huddl"
    Then I should see "Successfully RSVPed to this huddl!"
    And I should see "You're attending!"
    And I should see "1 person attending"

  Scenario: Multiple users can manage their RSVPs independently
    Given I am logged in as "organizer@example.com"
    And I have RSVPed to "Virtual Code Review"
    And "member@example.com" has RSVPed to "Virtual Code Review"
    When I visit the "Virtual Code Review" huddl page
    Then I should see "2 people attending"
    
    When I click "Cancel RSVP"
    Then I should see "RSVP cancelled successfully"
    And I should see "1 person attending"
    
    When I log out
    And I am logged in as "member@example.com"
    And I visit the "Virtual Code Review" huddl page
    Then I should see "You're attending!"
    And I should see "1 person attending"

  Scenario: Cannot cancel RSVP for past events
    Given I am logged in as "member@example.com"
    And the following huddl exists in "Tech Meetup":
      | title        | description    | event_type | starts_at      | ends_at        |
      | Past Event   | Already done   | virtual    | yesterday 2pm  | yesterday 3pm  |
    And I have RSVPed to "Past Event"
    When I visit the "Past Event" huddl page
    Then I should not see "Cancel RSVP"
    And I should not see "RSVP to this huddl"
    But I should see "1 person attending"