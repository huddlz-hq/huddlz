@async @database @conn @account_deletion
Feature: People delete their own account
  As a person who no longer wants to use huddlz
  I want to delete my account from the app
  So that my details are gone while the groups I was part of keep their history

  Background:
    Given the following users exist:
      | email                 | role | display_name |
      | leave801@example.com  | user | Lee Leaving  |
      | owner801@example.com  | user | Owner Olive  |
      | member801@example.com | user | Member Maya  |
    And the user "leave801@example.com" has password "Password123!"
    And a public group "Deletion Book Club" exists with owner "owner801@example.com"
    And "leave801@example.com" is a member of "Deletion Book Club"
    And "member801@example.com" is a member of "Deletion Book Club"

  Scenario: Deleting an account ends access everywhere
    Given "leave801@example.com" is signed in to the app with password "Password123!"
    And "leave801@example.com" has an API key
    When "leave801@example.com" deletes their account in the app with password "Password123!"
    Then the account is deleted
    And the app is signed out of the deleted account
    And the API key of "leave801@example.com" is rejected
    And nobody can sign in to the app as "leave801@example.com" with password "Password123!"
    And the deleted account keeps no personal details

  Scenario: Deleting an account gives up group memberships and upcoming spots
    Given the huddl "Next Chapter" exists in group "Deletion Book Club" hosted by "owner801@example.com"
    And "Next Chapter" has room for 1 people
    And "leave801@example.com" has RSVPed to "Next Chapter"
    And "member801@example.com" is on the waitlist for "Next Chapter"
    And "leave801@example.com" is signed in to the app with password "Password123!"
    When "leave801@example.com" deletes their account in the app with password "Password123!"
    Then the account is deleted
    And the deleted account is no longer a member of "Deletion Book Club"
    And the deleted account is no longer attending "Next Chapter"
    And "member801@example.com" is confirmed for "Next Chapter"

  Scenario: Shared history keeps a neutral name
    Given the past huddl "Last Chapter" exists in group "Deletion Book Club" hosted by "owner801@example.com"
    And "leave801@example.com" attended "Last Chapter"
    And "leave801@example.com" is signed in to the app with password "Password123!"
    When "leave801@example.com" deletes their account in the app with password "Password123!"
    And I am signed in as "member801@example.com"
    And I visit the huddl page for "Last Chapter"
    Then I should see "Deleted member"
    And I should not see "Lee Leaving"

  Scenario: Groups the person owns are archived and their upcoming huddlz cancelled
    Given a public group "Deletion Garden Club" exists with owner "leave801@example.com"
    And "member801@example.com" is a member of "Deletion Garden Club"
    And the huddl "Spring Planting" exists in group "Deletion Garden Club" hosted by "leave801@example.com"
    And "member801@example.com" has RSVPed to "Spring Planting"
    And "leave801@example.com" is signed in to the app with password "Password123!"
    When "leave801@example.com" deletes their account in the app with password "Password123!"
    Then the account is deleted
    And the group "Deletion Garden Club" is archived
    And the huddl "Spring Planting" is cancelled
    And the group "Deletion Book Club" is not archived

  Scenario: The wrong password keeps the account
    Given "leave801@example.com" is signed in to the app with password "Password123!"
    When "leave801@example.com" deletes their account in the app with password "NotMyPassword1!"
    Then the account deletion is refused with "That password isn't right."
    And the app is still signed in as "Lee Leaving"

  Scenario: The email address can be used again after deletion
    Given "leave801@example.com" is signed in to the app with password "Password123!"
    When "leave801@example.com" deletes their account in the app with password "Password123!"
    Then someone can register in the app as "leave801@example.com"
