@database @conn @audit_history
Feature: Attributable change history
  As a person troubleshooting a change
  I want meaningful changes to retain their author and details
  So that I do not have to guess what happened

  Scenario: An owner's edit is remembered
    Given the following users exist:
      | email                    | role | display_name |
      | audit-owner@example.com  | user | Audit Owner  |
    And a public group "Audit Crew" exists with owner "audit-owner@example.com"
    And the group "Audit Crew" has a huddl "Original title" at "Austin, TX"
    And I am signed in as "audit-owner@example.com"
    When I visit the edit page for huddl "Original title"
    And I fill in "Title" with "Corrected title"
    And I click the "Save changes" button
    Then I should see "Huddl updated successfully"
    And the history remembers the title change by "audit-owner@example.com"
