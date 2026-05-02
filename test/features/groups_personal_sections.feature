@async @database @conn
Feature: Groups Personal Sections
  As a logged-in user browsing the groups directory
  I want to see groups I host or have joined surfaced at the top
  So that I can find my own groups without scanning the full list

  Background:
    Given the following users exist:
      | email                    | role     | display_name |
      | owner@example.com        | verified | Group Owner  |
      | member@example.com       | verified | Member User  |
      | stranger@example.com     | verified | Stranger     |

  Scenario: Owner sees their group in the Hosting section
    Given a public group "Cyberpunk Builders" exists with owner "owner@example.com"
    And I am signed in as "owner@example.com"
    When I visit the groups page
    Then I should see "// Hosting"
    And I should see "Cyberpunk Builders"
    And I should not see "// Joined"

  Scenario: Member sees groups they joined in the Joined section
    Given a public group "Phoenix Devs" exists with owner "stranger@example.com"
    And "member@example.com" has joined the group "Phoenix Devs"
    And I am signed in as "member@example.com"
    When I visit the groups page
    Then I should see "// Joined"
    And I should see "Phoenix Devs"
    And I should not see "// Hosting"

  Scenario: Anonymous user sees no personal sections
    Given a public group "Phoenix Devs" exists with owner "stranger@example.com"
    When I visit the groups page
    Then I should not see "// Hosting"
    And I should not see "// Joined"
    And I should see "Phoenix Devs"

  Scenario: View all link navigates to the scoped view and shows all hosted groups
    Given "owner@example.com" hosts 7 public groups named "Heavy Group"
    And I am signed in as "owner@example.com"
    When I visit the groups page
    Then I should see "// Hosting"
    And I should see "View all"
    When I click "View all"
    Then I should see "Groups You Host"
    And I should see "Heavy Group 7"
    And I should not see "// Hosting"

  Scenario: Search filters sections and main grid together
    Given a public group "Cyberpunk Builders" exists with owner "owner@example.com"
    And a public group "Knitting Circle" exists with owner "stranger@example.com"
    And I am signed in as "owner@example.com"
    When I visit "/groups?q=cyberpunk"
    Then I should see "Cyberpunk Builders"
    And I should not see "Knitting Circle"
