@async @database @conn @issue407
Feature: Daylight-saving scheduling

  @dst_gap
  Scenario: A nonexistent spring-forward time is adjusted visibly
    Given I schedule a huddl during a daylight-saving gap
    When I enter a nonexistent local time
    Then the time advances by the daylight-saving gap
    And I see the resolved local time before saving
    And the saved UTC instant represents that resolved time

  @dst_overlap
  Scenario: I can choose either occurrence of an ambiguous fall-back time
    Given I schedule a huddl during a daylight-saving overlap
    When I enter an ambiguous local time
    Then the earlier occurrence is selected by default
    And both occurrences are labeled with their abbreviations
    When I choose the later occurrence
    Then the saved UTC instant represents the later occurrence
