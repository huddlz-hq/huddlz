@database @conn @agenda_home
Feature: Agenda is home
  As a signed-in person
  I want the agenda to be the first thing I see
  So that what's next is one click closer than the calendar grid

  Background:
    Given the following users exist:
      | email           | display_name | role    |
      | ada@example.com | Ada Park     | regular |

  Scenario: Signing in lands on the agenda
    Given a user exists with email "test@example.com" and password "Password123!"
    And the user navigates to the sign in page
    When the user enters "test@example.com" in the email field
    And the user enters "Password123!" in the password field
    And the user submits the password sign in form
    Then the user lands on the agenda

  Scenario: Agenda takes the Huddlz place in navigation
    Given I am signed in as "ada@example.com"
    When I visit "/agenda"
    Then navigation should identify "Agenda" as the current destination
    And navigation offers no "Huddlz" destination
    And navigation offers "Calendar"

  Scenario: The agenda is its own page
    Given I am signed in as "ada@example.com"
    And I am going to "Async Rust reading group" on day 16 of next month at "19:00"
    When I visit "/agenda"
    Then the page heading is "Agenda"
    And the agenda shows day 16 with "Async Rust reading group"
    And the agenda offers the "RSVPs" and "Groups" filters
    And the page offers no view switcher

  Scenario: The calendar opens on the week
    Given I am signed in as "ada@example.com"
    When I visit "/agenda"
    And I click link "Calendar"
    Then view choices should identify "Week" as current
    And the view choices are "Week" and "Month"

  Scenario: Each calendar view has its own address
    Given I am signed in as "ada@example.com"
    When I visit "/calendar/month"
    Then view choices should identify "Month" as current
    When I visit "/calendar/week"
    Then view choices should identify "Week" as current
