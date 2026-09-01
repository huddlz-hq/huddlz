@async @database @conn @issue403
Feature: Group and virtual huddl time zones

  @slice1
  Scenario: A virtual huddl defaults to the Group time zone
    Given my group's city uses "America/New_York"
    When I schedule a virtual huddl for 9:00 AM
    Then "America/New_York" is shown as its huddl time zone
    And the huddl is saved for 9:00 AM in that zone

  @slice2
  Scenario: I can choose another time zone for a virtual huddl
    Given my group's time zone is "America/New_York"
    When I schedule a virtual huddl in "America/Los_Angeles"
    Then its authoritative time is saved in "America/Los_Angeles"

  @slice3
  Scenario: Changing a group city does not reschedule existing huddlz
    Given my group has a virtual huddl at 9:00 AM in "America/New_York"
    When I change the group's city and Group time zone
    Then the existing huddl remains at 9:00 AM in "America/New_York"
    And new virtual huddlz default to the new Group time zone
