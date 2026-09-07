@async @database @conn @membership_visibility
Feature: Group membership visibility
  Members see private huddlz while they belong to a group.

  Background:
    Given the following users exist:
      | email                 | role | display_name |
      | owner311@example.com  | user | Owner Olive  |
      | member311@example.com | user | Member Maya  |
    And a public group "Membership Visibility" exists with owner "owner311@example.com"
    And a members-only huddl "Private planning" exists in "Membership Visibility"

  Scenario: Leaving immediately hides private huddlz
    Given "member311@example.com" is a member of "Membership Visibility"
    And I am signed in as "member311@example.com"
    When I visit the group page for "Membership Visibility"
    Then I should see the huddl card "Private planning"
    When I click the "Leave Group" button
    Then the leave confirmation should explain that RSVPs are preserved
    When I click the "Yes, leave group" button
    Then I should not see the huddl card "Private planning"
    And the group member count should be 1
    And the "Join Group" button should be visible

  Scenario: Joining and rejoining reveal private huddlz and member identities
    Given I am signed in as "member311@example.com"
    When I visit the group page for "Membership Visibility"
    Then I should not see the huddl card "Private planning"
    And group member identities should be hidden
    When I click the "Join Group" button
    Then I should see the huddl card "Private planning"
    And I should see the group member "Owner Olive"
    And the group member count should be 2
    When I click the "Leave Group" button
    And I click the "Yes, leave group" button
    Then I should not see the huddl card "Private planning"
    And group member identities should be hidden
    When I click the "Join Group" button
    Then I should see the huddl card "Private planning"
    And I should see the group member "Owner Olive"
    And the group member count should be 2

  Scenario: Removal clears a mounted past tab and a pending leave dialog
    Given "member311@example.com" is a member of "Membership Visibility"
    And a past members-only huddl "Private retrospective" exists in "Membership Visibility"
    And I am signed in as "member311@example.com"
    When I visit the group page for "Membership Visibility"
    And I click link "Past"
    Then I should see the huddl card "Private retrospective"
    When I click the "Leave Group" button
    And the owner removes me from "Membership Visibility" in another session
    Then I should not see the huddl card "Private retrospective"
    And group member identities should be hidden
    And the leave confirmation should be closed
    When I submit stale group interactions
    Then I should not see the huddl card "Private planning"
    And I should not see the huddl card "Private retrospective"
    And the "Join Group" button should be visible

  Scenario: Organizer demotion removes privileged group actions
    Given "member311@example.com" is an organizer of "Membership Visibility"
    And I am signed in as "member311@example.com"
    When I visit the group page for "Membership Visibility"
    Then the huddl creation action should be visible
    When the owner demotes me in "Membership Visibility" in another session
    Then the huddl creation action should be hidden
    And I should see the huddl card "Private planning"

  Scenario: Former members cannot navigate directly to a private huddl
    Given "member311@example.com" is a member of "Membership Visibility"
    And I am signed in as "member311@example.com"
    When I visit the group page for "Membership Visibility"
    And I click the "Leave Group" button
    And I click the "Yes, leave group" button
    And I try to open the private huddl directly
    Then I should see the branded not found recovery page
