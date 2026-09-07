@browser_smoke @calendar_browser
Feature: Calendar browser time zone
  Scenario: The browser zone moves a late Denver huddl to the following day
    Given I attend a Denver huddl late on July 15
    When I open Calendar in a New York browser
    Then the huddl appears on July 16 with its Denver local time
