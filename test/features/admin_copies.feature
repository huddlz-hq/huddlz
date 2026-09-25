@database @conn @admin_copies
Feature: The admin overview shows how often huddlz are copied
  As the person running huddlz
  I want to see how often organizers copy a huddl instead of starting from scratch
  So that I know whether copying earns its place and where to take it next

  Background:
    Given the following users exist:
      | email                | role  | display_name |
      | admin642@example.com | admin | Admin Alex   |
      | owner642@example.com | user  | Owner Olive  |
      | host642@example.com  | user  | Host Hana    |
    And a public group "Tuesday Runners" exists with owner "owner642@example.com"
    And a public group "Book Club" exists with owner "host642@example.com"
    And copy measurement began 120 days ago

  Scenario: Counting copies in a period
    Given "owner642@example.com" copied 2 huddlz of "Tuesday Runners"
    And "owner642@example.com" created a huddl of "Tuesday Runners" from scratch
    And I am signed in as "admin642@example.com"
    When I visit "/admin"
    Then the Copies panel shows 2 for "Huddlz copied"
    And the Copies panel says "by 1 organizer in 1 group"
    And the Copies panel does not mention unavailable source timing

  Scenario: Organizers and groups are counted once each
    Given "owner642@example.com" copied 2 huddlz of "Tuesday Runners"
    And "host642@example.com" copied 1 huddl of "Book Club"
    And I am signed in as "admin642@example.com"
    When I visit "/admin"
    Then the Copies panel shows 3 for "Huddlz copied"
    And the Copies panel says "by 2 organizers in 2 groups"

  Scenario: Past and upcoming sources are counted apart
    Given "owner642@example.com" copied a huddl of "Tuesday Runners" that had already happened
    And "owner642@example.com" copied a huddl of "Tuesday Runners" that was still upcoming
    And I am signed in as "admin642@example.com"
    When I visit "/admin"
    Then the Copies panel shows 1 for "Copied from a past huddl"
    And the Copies panel shows 1 for "Copied from an upcoming huddl"

  Scenario: A source counts as it was when it was copied
    Given "owner642@example.com" copied a huddl of "Tuesday Runners" 20 days ago that ended 10 days ago
    And I am signed in as "admin642@example.com"
    When I visit "/admin"
    Then the Copies panel shows 0 for "Copied from a past huddl"
    And the Copies panel shows 1 for "Copied from an upcoming huddl"

  Scenario: The panel follows the period and compares it with the one before
    Given "owner642@example.com" copied a huddl of "Tuesday Runners" 70 days ago
    And "owner642@example.com" copied a huddl of "Tuesday Runners" 45 days ago
    And "owner642@example.com" copied a huddl of "Tuesday Runners" 5 days ago
    And I am signed in as "admin642@example.com"
    When I visit "/admin?period=30d"
    Then the Copies panel shows 1 for "Huddlz copied"
    And the Copies panel says "1 in the previous 30 days"

  Scenario: Nothing copied
    Given "owner642@example.com" created a huddl of "Tuesday Runners" from scratch
    And I am signed in as "admin642@example.com"
    When I visit "/admin"
    Then the Copies panel says "No huddlz were copied in this period."

  Scenario: A period that starts before copies were recorded
    Given copy measurement began 10 days ago
    And "owner642@example.com" copied a huddl of "Tuesday Runners" 10 days ago
    And I am signed in as "admin642@example.com"
    When I visit "/admin?period=90d"
    Then the Copies panel says it has been measured since 10 days ago
    And the Copies panel does not compare with the previous period

  Scenario: A period the records cover says nothing about measuring
    Given "owner642@example.com" copied a huddl of "Tuesday Runners" 60 days ago
    And I am signed in as "admin642@example.com"
    When I visit "/admin?period=30d"
    Then the Copies panel does not say when it has been measured since

  Scenario: The figures come with the platform overview action
    Given "owner642@example.com" copied 2 huddlz of "Tuesday Runners"
    When "admin642@example.com" runs the platform overview action
    Then its copy figures count 2 huddlz by 1 organizer

  Scenario: Later source edits do not rewrite copy history
    Given "owner642@example.com" copied a past huddl of "Tuesday Runners" which was later moved into the future
    And I am signed in as "admin642@example.com"
    When I visit "/admin"
    Then the Copies panel shows 1 for "Copied from a past huddl"
    And the Copies panel shows 0 for "Copied from an upcoming huddl"

  Scenario: Measurement coverage exists before the first copy
    Given copy measurement began 10 days ago
    And I am signed in as "admin642@example.com"
    When I visit "/admin?period=90d"
    Then the Copies panel says it has been measured since 10 days ago
    And the Copies panel does not compare with the previous period

  Scenario: Organizers remain distinct after their account links are removed
    Given "owner642@example.com" copied 2 huddlz of "Tuesday Runners"
    And "host642@example.com" copied 1 huddl of "Book Club"
    And the copying organizers are no longer linked to their accounts
    And I am signed in as "admin642@example.com"
    When I visit "/admin"
    Then the Copies panel says "by 2 organizers in 2 groups"

  Scenario: Aggregate copy counts include private groups without granting group access
    Given copy measurement began 120 days ago
    And a private group "Hidden Club" exists with owner "owner642@example.com"
    And "owner642@example.com" copied a huddl of "Hidden Club" 10 days ago
    And I am signed in as "admin642@example.com"
    When I visit "/admin?period=30d"
    Then the Copies panel shows 1 for "Huddlz copied"
    And the Copies panel says "0 in the previous 30 days"
    And the Copies panel does not say when it has been measured since
    And "admin642@example.com" still cannot read the copied huddl

  Scenario: Earlier copies with no recorded source timing are counted honestly
    Given "owner642@example.com" made a copy of "Tuesday Runners" before source timing was recorded
    And I am signed in as "admin642@example.com"
    When I visit "/admin"
    Then the Copies panel shows 1 for "Huddlz copied"
    And the Copies panel shows 0 for "Copied from a past huddl"
    And the Copies panel shows 0 for "Copied from an upcoming huddl"
    And the Copies panel shows 1 for "Source timing unavailable"

  Scenario: Fully measured periods with no copies still compare
    Given copy measurement began 120 days ago
    And I am signed in as "admin642@example.com"
    When I visit "/admin?period=30d"
    Then the Copies panel says "0 in the previous 30 days"
    And the Copies panel does not say when it has been measured since

  Scenario: Aggregate copy counts include private huddlz in public groups
    Given "owner642@example.com" made a private copy in "Tuesday Runners" 5 days ago
    And "owner642@example.com" made a private copy in "Tuesday Runners" 45 days ago
    And I am signed in as "admin642@example.com"
    When I visit "/admin?period=30d"
    Then the Copies panel shows 1 for "Huddlz copied"
    And the Copies panel says "1 in the previous 30 days"
    And "admin642@example.com" still cannot read the copied huddl

  Scenario: Aggregate copy counts include drafts without exposing them
    Given "owner642@example.com" made a draft copy in "Tuesday Runners"
    And I am signed in as "admin642@example.com"
    When I visit "/admin"
    Then the Copies panel shows 1 for "Huddlz copied"
    And "admin642@example.com" still cannot read the copied huddl

  Scenario: Deleting a copy does not erase its recorded adoption
    Given "owner642@example.com" made a draft copy in "Tuesday Runners"
    And "owner642@example.com" deleted their copied huddl
    And I am signed in as "admin642@example.com"
    When I visit "/admin"
    Then the Copies panel shows 1 for "Huddlz copied"
