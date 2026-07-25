@async @database @conn
Feature: Help page
  As any visitor (signed in or not)
  I want a /help page that points me to support, developer tools, and legal info
  So that I can find the answer I need without asking around

  Background:
    Given the following users exist:
      | email             | role     | display_name |
      | helpuser@example.com | verified | Help User |

  Scenario: Anonymous visitor sees the help sections
    When I visit "/help"
    Then I should see "Support"
    And I should see "Developers"
    And I should see "Legal and community"
    And I should see "About huddlz"

  Scenario: Anonymous visitor sees signed-out chrome
    When I visit "/help"
    Then I should see "Sign in"
    And I should see "Sign up"

  Scenario: Signed-in user sees the v3 sidebar with Help highlighted
    Given I am signed in as "helpuser@example.com"
    When I visit "/help"
    Then I should see "Support"
    And I should see "Help User"
