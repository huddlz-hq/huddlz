@async @database @conn
Feature: Notification preferences page
  As a user
  I want to control which emails huddlz sends me
  So that my inbox reflects what I actually care about

  Scenario: The notifications page holds only notification preferences
    Given I am signed in as "settings@example.com" with password "Password123!"
    When I visit "/profile/notifications"
    Then I should see "Notifications" as the page heading
    And I should see "Choose which emails huddlz sends you"
    And I should not see "Theme"
    And I should see "Your group role changed"
    When I uncheck "Confirmation when I RSVP to a huddl"
    And I click "Save preferences"
    Then I should see "Notification preferences saved"

  Scenario: User can reach notification preferences from the sidebar
    Given I am signed in as "linknav@example.com" with password "Password123!"
    When I go to my profile page
    And I click "Notifications" in the sidebar
    Then I should see "Choose which emails huddlz sends you"
    And the sidebar marks "Notifications" as the current page
