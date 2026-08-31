@async @database @conn
Feature: Group opportunities in Today

  Scenario: A group member sees a published opportunity without an RSVP
    Given I am an accepted member of a group
    And the group has a published huddl scheduled today
    And I have not responded to the huddl
    When I visit Calendar
    Then I see the huddl in Today
    And the huddl has no Personal relationship marker

  Scenario: A private group member sees its published huddl
    Given I am an accepted member of a private group
    And the group has a published huddl scheduled today
    And I have not responded to the huddl
    When I visit Calendar
    Then I see the huddl in Today

  Scenario: A pending group invitation does not reveal a huddl
    Given I have a pending invitation to a group
    And the group has a published huddl scheduled today
    When I visit Calendar
    Then I do not see the huddl in Today

  Scenario: Draft and unrelated public huddlz are absent
    Given I am an accepted member of a group with a draft huddl scheduled today
    And another public group has a published huddl scheduled today
    And I have no relationship with that other group's huddl
    When I visit Calendar
    Then I do not see the draft huddl
    And I do not see the unrelated public huddl
