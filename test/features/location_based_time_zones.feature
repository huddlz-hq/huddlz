@time_zones @async @database @conn
Feature: Location-based time zones
  Groups and huddlz use the time zone of the place where they belong
  so schedules stay correct regardless of where someone opens huddlz.

  Background:
    Given the following users exist:
      | email             | role     | display_name |
      | owner@example.com | verified | Group Owner  |
    And I am signed in as "owner@example.com"

  Scenario: A group's required city determines its time zone
    When I visit "/groups/new"
    And I fill in "Group name" with "Saint Augustine Neighbors"
    And I select "Saint Augustine, FL, USA" as the group city in "America/New_York"
    And I click "Create group"
    Then I should see "Group created successfully"
    And the group "Saint Augustine Neighbors" should use "America/New_York"

  Scenario: A group cannot be created without a city
    When I visit "/groups/new"
    And I fill in "Group name" with "Locationless Neighbors"
    And I click "Create group"
    Then I should see an error on the "Location" field
    And the group "Locationless Neighbors" should not exist

  Scenario: A group cannot be created with an unresolved home location
    When I try to create the group "Unresolved Neighbors" with an unresolved home location
    Then I should be told that the group location must be resolved
    And the group "Unresolved Neighbors" should not exist

  Scenario: A virtual huddl uses its group's time zone
    Given my group "Saint Augustine Neighbors" is based in "America/New_York"
    When I visit the new huddl page for "Saint Augustine Neighbors"
    And I fill in the huddl form with:
      | Field        | Value                    |
      | Title        | Morning Video Check-in   |
      | Description  | A remote morning meeting |
      | Date         | 2030-07-15               |
      | Start Time   | 09:00                    |
      | Duration     | 1 hour                   |
      | Huddl Type   | Virtual                  |
      | Virtual Link | https://example.com/room |
    And I submit the form
    Then the huddl "Morning Video Check-in" should be at 9:00 AM in "America/New_York"

  Scenario: A physical huddl uses the saved venue's time zone
    Given my group "Saint Augustine Neighbors" is based in "America/New_York"
    And the group has a saved venue "Denver Library" in "America/Denver"
    When I visit the new huddl page for "Saint Augustine Neighbors"
    And I fill in the huddl form with:
      | Field             | Value             |
      | Title             | Denver Book Night |
      | Description       | Books in Denver   |
      | Date              | 2030-07-15        |
      | Start Time        | 19:00             |
      | Duration          | 1 hour            |
      | Huddl Type        | In-Person         |
      | Physical Location | Denver Library    |
    And I submit the form
    Then the huddl "Denver Book Night" should be at 7:00 PM in "America/Denver"

  Scenario: A missing saved location cannot be used for a huddl
    Given my group "Saint Augustine Neighbors" is based in "America/New_York"
    When I try to schedule a physical huddl with a saved location that no longer exists
    Then I should be told that the saved location is unavailable
    And the huddl "Missing Location Huddl" should not exist

  Scenario: A typed address without a resolved time zone cannot be used for a huddl
    Given my group "Saint Augustine Neighbors" is based in "America/New_York"
    When I try to schedule a physical huddl using only a typed address
    Then I should be told to select a resolved saved location
    And the huddl "Typed Address Huddl" should not exist

  Scenario: Moving a group affects new virtual huddlz, not existing ones
    Given my group has a virtual huddl at 9:00 AM in "America/New_York"
    When I move the group to "America/Denver"
    Then the existing virtual huddl remains at 9:00 AM in "America/New_York"
    And a new virtual huddl uses "America/Denver"

  Scenario: Moving a physical huddl preserves the venue-local time
    Given a physical huddl is at 9:00 AM in "America/New_York"
    When I move the huddl to a venue in "America/Denver"
    Then the moved huddl is at 9:00 AM in "America/Denver"

  Scenario: A venue move sends the corrected time and calendar entry
    Given an attendee is going to a physical huddl at 9:00 AM in "America/New_York"
    When the organizer moves the huddl to a venue in "America/Denver"
    Then the attendee should receive the updated time as "Mon Jul 15, 2030 at 9:00 AM MDT"
    And adding the update to a Denver calendar should show 9:00 AM

  Scenario: Editing starts with the huddl-local wall time
    Given a physical huddl is at 9:00 AM in "America/New_York"
    When I open its edit form from a browser in "America/Denver"
    Then the edit form should show "09:00" in "America/New_York"

  Scenario: A recurring huddl keeps its wall-clock time across daylight saving
    Given a weekly virtual huddl starts at 9:00 AM before Eastern daylight saving time
    When the recurring schedule crosses the daylight-saving transition
    Then every occurrence starts at 9:00 AM in "America/New_York"
    And attendees in UTC see the start time shift by one hour

  Scenario: Editing a recurring schedule updates future wall-clock times
    Given a weekly virtual huddl starts at 9:00 AM before Eastern daylight saving time
    And the recurring schedule crosses the daylight-saving transition
    When I change the whole recurring series to 10:00 AM
    Then every future occurrence starts at 10:00 AM in "America/New_York"

  Scenario: An ambiguous fall-back time uses the earlier occurrence
    Given my group "Saint Augustine Neighbors" is based in "America/New_York"
    When I visit the new huddl page for "Saint Augustine Neighbors"
    And I enter November 3, 2030 at 1:30 AM
    Then I should see "America/New_York"
    And I should see "EDT (UTC-04:00)"

  Scenario: A nonexistent spring-forward time is rejected
    Given my group "Saint Augustine Neighbors" is based in "America/New_York"
    When I try to schedule a virtual huddl on March 10, 2030 at 2:30 AM
    Then I should see "does not exist in America/New_York because of daylight saving time"
    And the huddl "Spring Forward Huddl" should not exist

  Scenario: Calendar groups by the browser zone while showing the huddl zone
    Given I am attending a Denver huddl at 11:30 PM on July 15, 2030
    When I view Calendar from a browser in "America/New_York"
    Then Calendar should show "America/New_York" as the zone in use
    And the Denver huddl should appear on July 16
    And its calendar time should be "11:30 PM MDT"

  Scenario: Huddl details use the huddl's own time zone
    Given I am attending a Denver huddl at 11:30 PM on July 15, 2030
    When I open the Denver huddl from a browser in "America/New_York"
    Then its details should show "Mon, Jul 15 11:30 PM"
    And its details should show "MDT"

  Scenario: RSVP confirmation uses the huddl's own time zone
    Given I am attending a Denver huddl at 11:30 PM on July 15, 2030
    Then my confirmation should say "Mon Jul 15, 2030 at 11:30 PM MDT"

  Scenario: The API returns UTC timestamps with the huddl time zone
    Given I am attending a Denver huddl at 11:30 PM on July 15, 2030
    When I request that huddl through the JSON API
    Then the API start should be "2030-07-16T05:30:00Z"
    And the API time zone should be "America/Denver"

  Scenario: Search date boundaries come from the search location
    Given the current time falls on different dates in Saint Augustine and Denver
    And a Saint Augustine huddl starts at 9:00 AM on September 15, 2030
    When I search this month within 25 miles of Saint Augustine
    Then the Saint Augustine huddl should be found
    And its search time should be "9:00 AM EDT"

  Scenario: A calendar-period search requires a resolved time zone
    When I search this month near a location without a resolved time zone
    Then the search should require a resolved time zone

  Scenario: A saved home search keeps its own time zone
    Given my saved home search is Saint Augustine in "America/New_York"
    When I filter Discover to this month from a browser in "America/Denver"
    Then the search should still use "America/New_York"

  Scenario: An older shared search link still searches its location
    When I open an older 25-mile Saint Augustine search link
    Then Discover should still search near "Saint Augustine, FL"
