@database @conn
Feature: Calendar relationship markers

  Scenario: A confirmed RSVP is marked Going
    Given I am signed in
    And I have a confirmed RSVP for a published huddl scheduled today
    When I visit Calendar
    Then I see the huddl once
    And the huddl is marked "Going"

  Scenario: A creator who also has a confirmed RSVP is marked Hosting once
    Given I am signed in
    And I created a published huddl scheduled today
    And I also have a confirmed RSVP for that huddl
    When I visit Calendar
    Then I see the huddl once
    And the huddl is marked "Hosting"
    And the huddl is not marked "Going"

  Scenario: A waitlisted RSVP is marked Waitlisted
    Given I am signed in
    And I am waitlisted for a published huddl scheduled today
    When I visit Calendar
    Then I see the huddl once
    And the huddl is marked "Waitlisted"

  Scenario: An organizer who did not create the huddl is not marked Hosting
    Given I am signed in
    And I organize a group
    And another organizer created a published group huddl scheduled today
    And I have not responded to the huddl
    When I visit Calendar
    Then I see the huddl once
    And the huddl is not marked "Hosting"
