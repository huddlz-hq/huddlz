@async @database @conn
Feature: Current navigation for assistive technology
  As a person using assistive technology
  I want to know which destination and view are selected
  So that I can navigate without relying on visual styling

  Background:
    Given the following users exist:
      | email                | display_name    | role    |
      | attendee@example.com | Navigation User | regular |
    And I am signed in as "attendee@example.com"

  Scenario: Current destination and view follow navigation
    When I visit "/calendar"
    Then navigation should identify "Calendar" as the current destination
    And view choices should identify "Agenda" as current
    When I click link "Agenda"
    Then view choices should identify "Agenda" as current
    When I click link "Discover"
    Then navigation should identify "Discover" as the current destination
    And view choices should identify "Huddlz" as current
    When I choose the "Groups" view
    Then view choices should identify "Groups" as current
