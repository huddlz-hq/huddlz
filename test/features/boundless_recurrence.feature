@async @database @conn @boundless_recurrence
Feature: Recurring huddlz keep themselves going
  As a group organizer
  I want a recurring huddl to continue without me repeating myself
  So that members always see the next few dates

  Scenario: The scheduled run keeps a boundless series stocked
    Given a weekly huddl that repeats with no end date
    When the scheduled recurrence run happens
    Then the series should have 12 upcoming dates
    When the scheduled recurrence run happens
    Then the series should have 12 upcoming dates

  Scenario: A cancelled date is not recreated
    Given a weekly huddl that repeats with no end date
    And the scheduled recurrence run has happened
    When the organizer cancels the fourth upcoming date
    And the scheduled recurrence run happens
    Then that date should remain cancelled
    And the series should have 11 upcoming dates

  Scenario: Changing the frequency re-spaces the series without adding dates
    Given a monthly huddl that repeats with no end date
    And the scheduled recurrence run has happened
    When the organizer changes the whole series to weekly
    Then the series should have 12 upcoming dates
    And the upcoming dates should be a week apart

  Scenario: Extending the end date waits for the scheduled run
    Given a weekly huddl that repeats until three weeks from now
    And the scheduled recurrence run has happened
    When the organizer extends the whole series by three months
    Then the series should have 3 upcoming dates
    When the scheduled recurrence run happens
    Then the series should have 12 upcoming dates
