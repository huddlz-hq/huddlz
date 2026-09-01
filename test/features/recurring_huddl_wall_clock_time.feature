@async @database @conn @issue409
Feature: Recurring huddl wall-clock time

  Scenario: A weekly huddl retains its wall-clock time across daylight saving
    Given I schedule a weekly huddl for 9:00 AM in "America/New_York"
    And the series crosses a daylight-saving transition
    When its occurrences are generated
    Then every occurrence starts at 9:00 AM in "America/New_York"
    And the corresponding UTC time changes across the transition
    And each occurrence remains independently actionable
