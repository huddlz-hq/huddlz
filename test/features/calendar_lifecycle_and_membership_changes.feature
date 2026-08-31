@calendar_lifecycle_membership @database @conn
Feature: Calendar lifecycle and membership changes

  Scenario: A cancelled Personal huddl remains visible
    Given I am signed in
    And I was going to a huddl scheduled today
    And the huddl has been cancelled
    When I visit Calendar
    Then I see the huddl once
    And the huddl is marked "Cancelled"

  Scenario: A cancelled uncommitted Group opportunity disappears
    Given I am an accepted member of a group
    And the group has a cancelled huddl scheduled today
    And I never responded to the huddl
    When I visit Calendar
    Then I do not see the huddl

  Scenario: Leaving a public group removes opportunities but preserves Personal huddlz
    Given I left a public group
    And the group has one published huddl scheduled today that I never responded to
    And the group has another published huddl scheduled today that I am going to
    When I visit Calendar
    Then I do not see the huddl I never responded to
    And I see the huddl I am going to marked "Going"

  Scenario: Leaving a private group does not bypass private access rules
    Given I left a private group
    And I no longer have permission to view its huddlz
    When I visit Calendar
    Then I do not see the private group's huddlz
