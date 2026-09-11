@async @database @conn
Feature: Notification preferences
  As a user
  I want to control which emails huddlz sends me
  So that my inbox reflects what I actually care about

  Scenario: Turning an email off saves right away
    Given I am signed in as "settings@example.com" with password "Password123!"
    When I visit "/profile/notifications"
    And I turn off "Confirmation when I RSVP to a huddl"
    Then the page confirms the change was saved
    And there is no Save button
    When I visit "/profile/notifications"
    Then "Confirmation when I RSVP to a huddl" is off

  Scenario: Digests stay hidden until they exist
    Given I am signed in as "digest@example.com" with password "Password123!"
    When I visit "/profile/notifications"
    Then I should not see "Digests"
    And "Weekly digest of upcoming huddlz" has no switch

  Scenario: Essentials are listed without switches
    Given I am signed in as "essentials@example.com" with password "Password123!"
    When I visit "/profile/notifications"
    Then the always-sent list names "Password changed"
    And "Password changed" has no switch

  Scenario: User can reach notification preferences from the sidebar
    Given I am signed in as "linknav@example.com" with password "Password123!"
    When I go to my profile page
    And I click "Notifications" in the sidebar
    Then I should see "Choose which emails huddlz sends you"
    And the sidebar marks "Notifications" as the current page
