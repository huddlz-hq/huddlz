@async @database @conn @copy_huddl
Feature: Copy a huddl
  As an organizer
  I want to start a new huddl from one my group already ran
  So that I can run the same gathering again without retyping it

  Scenario: Copying a past huddl from its page
    Given I organize a group with a past huddl "Hands-on with Ash Framework"
    When I visit that huddl and choose to copy it
    Then I see the new huddl form filled in from "Hands-on with Ash Framework"
    And the date suggested is the next matching weekday
    When I schedule the huddl
    Then the group has a new upcoming "Hands-on with Ash Framework"
    And the past huddl is unchanged

  Scenario: Copying from the organizer list
    Given I organize a group with a past huddl "Hands-on with Ash Framework"
    When I copy it from the past huddlz on the organizer page
    Then I see the new huddl form filled in from "Hands-on with Ash Framework"

  Scenario: Copying an upcoming huddl
    Given I organize a group with an upcoming huddl "Elixir study night"
    When I visit that huddl and choose to copy it
    Then the date suggested is a week after that huddl

  Scenario: Leaving without saving creates nothing
    Given I organize a group with a past huddl "Hands-on with Ash Framework"
    When I visit that huddl and choose to copy it
    And I leave the form without saving
    Then the group has no new huddl

  Scenario: The cover comes along as a copy
    Given I organize a group with a past huddl "Hands-on with Ash Framework"
    And that huddl has a cover image
    When I visit that huddl and choose to copy it
    Then the form shows a copy of the original's cover
    When I schedule the huddl
    Then the new huddl has its own copy of the cover image
    When I remove the saved copy's cover
    Then the original cover is still available

  Scenario: Removing the copied cover
    Given I organize a group with a past huddl "Hands-on with Ash Framework"
    And that huddl has a cover image
    When I visit that huddl and choose to copy it
    And I remove the copied cover
    And I schedule the huddl
    Then the new huddl has no cover image
    And the original still has its cover image

  Scenario: The original's location was removed
    Given I organize a group with a past huddl "Hands-on with Ash Framework"
    And its location was removed from the address book
    When I visit that huddl and choose to copy it
    Then I am told the original's location was removed and to choose one

  Scenario: A copy of a series huddl starts as a one-off
    Given I organize a group with a weekly series "Elixir study night"
    When I visit that huddl and choose to copy it
    Then the new huddl form is not set to repeat
    And I am told the copy is a one-off from a weekly series

  Scenario: Members cannot copy
    Given a group I belong to as a member has a past huddl "Hands-on with Ash Framework"
    When I visit that huddl
    Then I cannot copy it

  Scenario: A copy link for another group's huddl opens an empty form
    Given I organize a group with a past huddl "Hands-on with Ash Framework"
    And I organize another group
    When I open the new huddl form for the other group copying that huddl
    Then the new huddl form is empty

  Scenario: Copying a huddl with a 45-minute duration
    Given I organize a group with a 45-minute huddl
    When I visit that huddl and choose to copy it
    Then the copied duration is 45 minutes
    When I schedule the huddl
    Then the group has a new upcoming "Quick study session"
