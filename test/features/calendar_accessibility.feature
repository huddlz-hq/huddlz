@async @database @conn
Feature: Accessible personal calendar
  As a person using assistive technology
  I want calendar huddl links to describe my relationship to each huddl
  So that every link makes sense outside the visual layout

  Background:
    Given the following users exist:
      | email                | display_name | role    |
      | attendee@example.com | Calendar User | regular |
    And I am signed in as "attendee@example.com"

  Scenario: A past attended huddl keeps its attendance context
    Given I attended a past huddl named "Retrospective"
    When I open the calendar month containing that huddl
    Then the "Retrospective" calendar link should identify it as attended and past
