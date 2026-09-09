@database @conn @group_settings
Feature: Owner-only group settings
  Owners manage group governance separately from the member roster.

  Scenario: The owner opens settings from the organizer workspace
    Given the following users exist:
      | email             | role | display_name |
      | owner@example.com | user | Owner        |
    And a public group "Council" exists with owner "owner@example.com"
    And I am signed in as "owner@example.com"
    When I visit "/organize/council/members"
    Then I should not see "Transfer group ownership"
    When I click "Group settings"
    Then I should see "Danger zone"
    And I should see "Edit group details"
    And I should see "Add a member before transferring ownership"

  Scenario: Transfer keeps the former owner in the organizer workspace
    Given the following users exist:
      | email              | role | display_name |
      | owner@example.com  | user | Owner        |
      | member@example.com | user | Successor    |
    And a public group "Council" exists with owner "owner@example.com"
    And "member@example.com" is a member of "Council"
    And I am signed in as "owner@example.com"
    When I visit "/organize/council/settings"
    And I select "Successor" from "New owner"
    And I click "Transfer group ownership"
    Then I should see "The selected member becomes the owner of Council"
    And I should see "You will become an organizer"
    And I should see "cannot reverse this transfer without the new owner’s cooperation"
    When I fill in "Type Council to confirm" with "Council"
    And I click "Transfer ownership"
    Then I should see "Ownership transferred to Successor"
    And I should not see "Group settings"
    When I click "Members"
    Then I should see "Successor"
    And I should not see "Transfer group ownership"
