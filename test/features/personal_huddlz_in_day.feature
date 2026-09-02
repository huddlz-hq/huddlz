@personal_huddlz_in_day @async @database @conn
Feature: Confirmed Personal huddlz in Day

  Scenario: A confirmed Personal huddl appears in the current Day
    Given I am signed in
    And I have a confirmed RSVP for a published huddl scheduled today
    And I am not a member of the group hosting the huddl
    When I visit Calendar
    Then the current date is selected
    And I see the huddl in chronological order
    And the huddl is marked "Going"
    When I select the huddl card
    Then I am taken to the huddl detail page

  Scenario: A saved Location label appears on the huddl card
    Given I am signed in
    And I have a confirmed RSVP for a published huddl scheduled today
    And the huddl uses a saved Location named "Downtown Library"
    When I visit Calendar
    Then I see "Downtown Library" on the huddl card
    And I do not see the Location's full street address on the huddl card
