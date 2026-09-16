@browser_smoke @organizer_navigation
Feature: Organizer navigation
  Scenario: An organizer opens a group workspace and its forms without reloading
    Given I have opened the workspace picker for my group
    When I open my group workspace
    Then the group workspace arrives without reloading the page
    When I follow the workspace link "Edit group"
    Then the "Edit Group" form arrives without reloading the page

