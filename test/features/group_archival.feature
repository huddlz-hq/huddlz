@database @conn
Feature: Group archival
  Group owners can close a group without losing its community and history.

  Scenario: An owner archives and restores a group
    Given the following users exist:
      | email             | role | display_name |
      | owner@example.com | user | Owner        |
    And a public group "Seasonal Club" exists with owner "owner@example.com"
    And I am signed in as "owner@example.com"
    When I visit the edit page for "Seasonal Club"
    And I click "Archive group"
    Then I should see "Members keep access to the group's history"
    When I click "Yes, archive group"
    Then I should see "Group archived"
    When I visit "/my-groups"
    Then I should not see "Seasonal Club"
    When I click "Archived"
    Then I should see "Seasonal Club"
    When I visit the group page for "Seasonal Club"
    Then I should see "This group is archived"
    When I click "Group settings"
    And I click "Restore group"
    Then I should see "Group restored"
    When I visit "/my-groups"
    Then I should see "Seasonal Club"

  Scenario: Members retain read-only history while outsiders lose access
    Given the following users exist:
      | email              | role | display_name |
      | owner@example.com  | user | Owner        |
      | member@example.com | user | Member       |
      | other@example.com  | user | Other        |
    And a public group "History Club" exists with owner "owner@example.com"
    And "member@example.com" is a member of "History Club"
    And the past huddl "Last summer" exists in group "History Club" hosted by "owner@example.com"
    And I am signed in as "owner@example.com"
    When I visit the edit page for "History Club"
    And I click "Archive group"
    And I click "Yes, archive group"
    Then I should not see "Edit Group"
    And I should not see "Create Huddl"
    Given I am signed in as "member@example.com"
    When I visit the group page for "History Club"
    Then I should see "This group is archived"
    When I open the archived huddl "Last summer"
    Then I should see "Last summer"
    And I should see "This group is archived"
    Given I am signed in as "other@example.com"
    When I try to visit the group page for "History Club"
    Then I should see the branded not found recovery page
    When I try to open the archived huddl "Last summer"
    Then I should see the branded not found recovery page

  Scenario: A group with upcoming huddlz cannot be archived
    Given the following users exist:
      | email             | role | display_name |
      | owner@example.com | user | Owner        |
    And a public group "Busy Club" exists with owner "owner@example.com"
    And the huddl "Next gathering" exists in group "Busy Club" hosted by "owner@example.com"
    And I am signed in as "owner@example.com"
    When I visit the edit page for "Busy Club"
    And I click "Archive group"
    And I click "Yes, archive group"
    Then I should see "Finish or cancel these huddlz before archiving"
    And I should see "Next gathering"
    When I visit the group page for "Busy Club"
    Then I should not see "This group is archived"

  Scenario: Archival notifies members once per closure
    Given the following users exist:
      | email              | role | display_name |
      | owner@example.com  | user | Owner        |
      | member@example.com | user | Member       |
    And a public group "Quiet Club" exists with owner "owner@example.com"
    And "member@example.com" is a member of "Quiet Club"
    And I am signed in as "owner@example.com"
    When I visit the edit page for "Quiet Club"
    And I click "Archive group"
    And I click "Yes, archive group"
    Then an archive email for "Quiet Club" should be sent to "member@example.com"
    Given I am signed in as "member@example.com"
    When I visit "/notifications"
    Then I should see "Archived: Quiet Club"
    And I can open the archived group from its notification

  Scenario: Archived groups reject membership changes even through the admin API
    Given the following users exist:
      | email              | role  | display_name |
      | owner@example.com  | user  | Owner        |
      | member@example.com | user  | Member       |
      | admin@example.com  | admin | Admin        |
    And a public group "Frozen Club" exists with owner "owner@example.com"
    And "member@example.com" is a member of "Frozen Club"
    And I am signed in as "owner@example.com"
    When I visit the edit page for "Frozen Club"
    And I click "Archive group"
    And I click "Yes, archive group"
    Given I am signed in as "admin@example.com"
    When I try to promote "member@example.com" in "Frozen Club" through the API
    Then the archived group change is rejected

  Scenario: Archived groups reject new address book locations through the admin API
    Given the following users exist:
      | email             | role  | display_name |
      | owner@example.com | user  | Owner        |
      | admin@example.com | admin | Admin        |
    And a public group "Closed Club" exists with owner "owner@example.com"
    And I am signed in as "owner@example.com"
    When I visit the edit page for "Closed Club"
    And I click "Archive group"
    And I click "Yes, archive group"
    Given I am signed in as "admin@example.com"
    When I try to add a location to "Closed Club" through the API
    Then the archived location change is rejected

  Scenario: Ownership can transfer without reopening an archived group
    Given the following users exist:
      | email              | role | display_name |
      | owner@example.com  | user | Owner        |
      | member@example.com | user | Successor    |
    And a public group "Legacy Club" exists with owner "owner@example.com"
    And "member@example.com" is a member of "Legacy Club"
    And I am signed in as "owner@example.com"
    When I visit the edit page for "Legacy Club"
    And I click "Archive group"
    And I click "Yes, archive group"
    And I click "Group settings"
    And I click "Manage ownership"
    Then I should see "This group is archived"
    When I transfer the archived group "Legacy Club" to "Successor"
    Then I should see "Ownership transferred to Successor"
    When I visit the group page for "Legacy Club"
    Then I should see "This group is archived"
    And I should not see "Group settings"
    Given I am signed in as "member@example.com"
    When I visit the group page for "Legacy Club"
    And I click "Group settings"
    And I click "Restore group"
    Then I should see "Group restored"

  Scenario: Archived huddl history has no photo upload controls
    Given the following users exist:
      | email             | role | display_name |
      | owner@example.com | user | Owner        |
    And a public group "Photo Club" exists with owner "owner@example.com"
    And the past huddl "Old outing" exists in group "Photo Club" hosted by "owner@example.com"
    And I am signed in as "owner@example.com"
    When I visit the edit page for "Photo Club"
    And I click "Archive group"
    And I click "Yes, archive group"
    And I open the archived huddl "Old outing"
    Then I should see "This group is archived"
    And the "Browse photos" button should not be visible

  Scenario: A form opened before archival cannot change the group
    Given the following users exist:
      | email             | role | display_name |
      | owner@example.com | user | Owner        |
    And a public group "Stale Club" exists with owner "owner@example.com"
    And I am signed in as "owner@example.com"
    When I visit the edit page for "Stale Club"
    And the owner archives "Stale Club" in another session
    And I fill in the following:
      | Description | This should not save |
    And I click "Save Changes"
    Then I should see "archived"
    When I visit the group page for "Stale Club"
    Then I should not see "This should not save"

  Scenario: An archived draft cannot be published through the API
    Given the following users exist:
      | email             | role | display_name |
      | owner@example.com | user | Owner        |
    And a public group "Draft Club" exists with owner "owner@example.com"
    And "Draft Club" has an unpublished huddl "Next season"
    And I am signed in as "owner@example.com"
    When I visit the edit page for "Draft Club"
    And I click "Archive group"
    And I click "Yes, archive group"
    And I try to publish "Next season" through the API
    Then the archived huddl change is rejected
    When I open the archived huddl "Next season"
    Then the "Publish huddl" button should not be visible

  Scenario: An outstanding invitation cannot reopen membership in an archived group
    Given the following users exist:
      | email              | role | display_name |
      | owner@example.com  | user | Owner        |
      | invitee@example.com | user | Invitee     |
    And a private group "Invitation Club" exists with owner "owner@example.com"
    And I am signed in as "owner@example.com"
    When I open the member workspace for "Invitation Club"
    And I submit a member invitation for "invitee@example.com"
    And I visit the edit page for "Invitation Club"
    And I click "Archive group"
    And I click "Yes, archive group"
    Given I am signed in as "invitee@example.com"
    When I open my invitation to "Invitation Club"
    Then I should see "This group is archived"
    And the "Accept invitation" button should not be visible

  Scenario Outline: Archived cover images cannot be replaced through the admin API
    Given the following users exist:
      | email             | role  | display_name |
      | owner@example.com | user  | Owner        |
      | admin@example.com | admin | Admin        |
    And a public group "Cover Club" exists with owner "owner@example.com"
    And the past huddl "Old cover" exists in group "Cover Club" hosted by "owner@example.com"
    And I am signed in as "owner@example.com"
    When I visit the edit page for "Cover Club"
    And I click "Archive group"
    And I click "Yes, archive group"
    Given I am signed in as "admin@example.com"
    When I upload an archived "<target>" cover through the API
    Then the archived cover upload is rejected

    Examples:
      | target |
      | group  |
      | huddl  |

  Scenario: Repeated archive requests do not repeat notifications and restoration permits another closure
    Given the following users exist:
      | email              | role | display_name |
      | owner@example.com  | user | Owner        |
      | member@example.com | user | Member       |
    And a public group "Repeat Club" exists with owner "owner@example.com"
    And "member@example.com" is a member of "Repeat Club"
    And I am signed in as "owner@example.com"
    When I visit the edit page for "Repeat Club"
    And the owner archives "Repeat Club" in another session
    And I click "Archive group"
    And I click "Yes, archive group"
    Then I should see "already archived"
    When I visit "/notifications"
    Then I should not see "Archived: Repeat Club"
    Given I am signed in as "member@example.com"
    When I visit "/notifications"
    Then I should see 1 archive notification for "Repeat Club"
    Given I am signed in as "owner@example.com"
    When I visit the edit page for "Repeat Club"
    And I click "Restore group"
    And I visit the edit page for "Repeat Club"
    And I click "Archive group"
    And I click "Yes, archive group"
    Given I am signed in as "member@example.com"
    When I visit "/notifications"
    Then I should see 2 archive notifications for "Repeat Club"

  Scenario Outline: Only owners and admins can archive through the API
    Given the following users exist:
      | email              | role  | display_name |
      | owner@example.com  | user  | Owner        |
      | member@example.com | user  | Member       |
      | admin@example.com  | admin | Admin        |
    And a public group "API Club" exists with owner "owner@example.com"
    And "member@example.com" is an organizer of "API Club"
    And I am signed in as "<actor>"
    When I archive "API Club" through the API
    Then API archival is "<outcome>"

    Examples:
      | actor              | outcome |
      | owner@example.com  | allowed |
      | admin@example.com  | allowed |
      | member@example.com | denied  |

  Scenario Outline: API clients can restore an archived group
    Given the following users exist:
      | email             | role | display_name |
      | owner@example.com | user | Owner        |
    And a public group "Restore API Club" exists with owner "owner@example.com"
    And I am signed in as "owner@example.com"
    When I close and restore "Restore API Club" through "<api>"
    And I visit the group page for "Restore API Club"
    Then I should not see "This group is archived"
    And I should see "Edit Group"

    Examples:
      | api      |
      | GraphQL  |
      | JSON:API |

  Scenario: Members can find cancelled public huddlz in archived history
    Given the following users exist:
      | email              | role | display_name |
      | owner@example.com  | user | Owner        |
      | member@example.com | user | Member       |
    And a public group "Cancelled Club" exists with owner "owner@example.com"
    And "member@example.com" is a member of "Cancelled Club"
    And the huddl "Cancelled outing" exists in group "Cancelled Club" hosted by "owner@example.com"
    And I am signed in as "owner@example.com"
    When I open the archived huddl "Cancelled outing"
    And I click "Cancel huddl"
    And I confirm cancelling the huddl
    And I visit the edit page for "Cancelled Club"
    And I click "Archive group"
    And I click "Yes, archive group"
    Given I am signed in as "member@example.com"
    When I visit the group page for "Cancelled Club"
    Then I should see "Cancelled outing"
    When I open the archived huddl "Cancelled outing"
    Then I should see "This group is archived"

  Scenario Outline: Archived addresses are available only to members
    Given the following users exist:
      | email              | role | display_name |
      | owner@example.com  | user | Owner        |
      | member@example.com | user | Member       |
      | other@example.com  | user | Other        |
    And a public group "Address Club" exists with owner "owner@example.com"
    And "member@example.com" is a member of "Address Club"
    And "Address Club" has a saved location named "Retained meeting place"
    And I am signed in as "owner@example.com"
    When I visit the edit page for "Address Club"
    And I click "Archive group"
    And I click "Yes, archive group"
    Given I am signed in as "<actor>"
    When I request archived addresses through "<api>"
    Then the retained address is "<visibility>"

    Examples:
      | actor              | api      | visibility |
      | member@example.com | GraphQL  | visible    |
      | other@example.com  | GraphQL  | hidden     |
      | member@example.com | JSON:API | visible    |
      | other@example.com  | JSON:API | hidden     |
