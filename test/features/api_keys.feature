@async @database @conn @api_keys
Feature: API keys
  As a person who lets scripts and AI agents use huddlz for me
  I want to create, review and revoke my API keys
  So that software acts as me only while I allow it

  Background:
    Given the following users exist:
      | email                    | display_name |
      | keys637@example.com      | Kim Keys     |
      | neighbour637@example.com | Nia Next     |

  Scenario: A new key is shown once
    Given I am signed in as "keys637@example.com"
    When I visit "/profile"
    And I click "API keys" in the sidebar
    Then the sidebar marks "API keys" as the current page
    And I should see "No keys yet"
    When I click "Create key"
    And I fill in "Name" with "Claude Code on my laptop"
    And I choose "90 days"
    And I click the "Create key" button
    Then I see my new key once
    And my new key works with the API
    When I click "Done"
    Then "Claude Code on my laptop" is listed as expiring in 90 days
    And the page no longer shows my new key

  Scenario: A key needs a name
    Given I am signed in as "keys637@example.com"
    When I visit "/profile/api-keys"
    And I click "Create key"
    And I click the "Create key" button
    Then I should see "is required"
    And I have no API keys

  Scenario: The list shows when a key was last used
    Given I am signed in as "keys637@example.com"
    And I have an API key named "Calendar sync script"
    When I visit "/profile/api-keys"
    Then "Calendar sync script" shows "Never used"
    When my key "Calendar sync script" is used with the API
    And I visit "/profile/api-keys"
    Then "Calendar sync script" shows "Used just now"

  Scenario: Revoking a key stops it working
    Given I am signed in as "keys637@example.com"
    And I have an API key named "Old laptop"
    When I visit "/profile/api-keys"
    And I click "Revoke" for "Old laptop"
    And I confirm with "Revoke"
    Then "Old laptop" is not listed
    And my key "Old laptop" is refused by the API

  Scenario: An expired key stays listed until removed
    Given I am signed in as "keys637@example.com"
    And I have an API key named "Codex on the work desktop" that expired yesterday
    When I visit "/profile/api-keys"
    Then "Codex on the work desktop" is marked expired
    And my key "Codex on the work desktop" is refused by the API
    When I click "Remove" for "Codex on the work desktop"
    Then "Codex on the work desktop" is not listed

  Scenario: Someone with an unconfirmed address has no API keys page
    Given "keys637@example.com" has not confirmed their address
    And I am signed in as "keys637@example.com"
    When I visit "/profile"
    Then the sidebar has no "API keys" entry
    When I visit "/profile/api-keys"
    Then I should see "Confirm your email address to create API keys"

  Scenario: People see only their own keys
    Given "neighbour637@example.com" has an API key named "Someone else's script"
    And I am signed in as "keys637@example.com"
    When I visit "/profile/api-keys"
    Then I should not see "Someone else's script"
