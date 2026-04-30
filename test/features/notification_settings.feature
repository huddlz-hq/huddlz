@async @database @conn
Feature: Notification preferences settings page
  As a user
  I want to control which emails huddlz sends me
  So that my inbox reflects what I actually care about

  Scenario: User opts out of an activity-tier notification
    Given I am signed in as "settings@example.com" with password "Password123!"
    When I visit "/profile/notifications"
    Then I should see "Notification preferences"
    And I should see "Activity"
    When I uncheck "Confirmation when I RSVP to a huddl"
    And I click "Save preferences"
    Then I should see "Notification preferences saved"

  Scenario: User can reach the notifications page from the profile page
    Given I am signed in as "linknav@example.com" with password "Password123!"
    When I go to my profile page
    And I click "Notification preferences"
    Then I should see "Choose which emails you want to receive"
