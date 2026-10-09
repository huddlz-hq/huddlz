@async @database @conn @intent_login
Feature: Intent-based login flow
  As a person signing in to huddlz
  I want to be asked once what I came for
  So that I land on my own huddlz or on Discover, whichever I meant

  Scenario: Signing in offers a choice and Find a new one reaches Discover
    Given a user exists with email "test+intent-discover@example.com" and password "Password123!"
    And the user navigates to the sign in page
    When the user enters "test+intent-discover@example.com" in the email field
    And the user enters "Password123!" in the password field
    And the user submits the password sign in form
    Then the user is asked what they came for
    When the user chooses "Find a new one"
    Then the user lands on discover

  Scenario: Signing in and choosing See my huddlz reaches the agenda
    Given a user exists with email "test+intent-agenda@example.com" and password "Password123!"
    And the user navigates to the sign in page
    When the user enters "test+intent-agenda@example.com" in the email field
    And the user enters "Password123!" in the password field
    And the user submits the password sign in form
    Then the user is asked what they came for
    When the user chooses "See my huddlz"
    Then the user lands on the agenda page

  Scenario: Someone arriving from a huddl link is never asked
    Given a user exists with email "test+intent-return@example.com" and password "Password123!"
    And a public group "Trail Runners" has a huddl "Sunrise 5k"
    And the user navigates to the sign in page for that huddl
    When the user enters "test+intent-return@example.com" in the email field
    And the user enters "Password123!" in the password field
    And the user submits the password sign in form
    Then the user is not asked what they came for
    And the user lands on the huddl "Sunrise 5k"

  # Any sign-in entry point that carries a destination must bypass the
  # question, not just the huddl page's own RSVP button. Extending that
  # coverage to the global header is variant A's deliverable; this scenario
  # pins that whichever link produced the destination, the question defers
  # to it.
  Scenario: Someone signing in from a huddl page's header link is never asked
    Given a user exists with email "test+intent-header@example.com" and password "Password123!"
    And a public group "Night Cyclists" has a huddl "Moonlight loop"
    And the user is on that huddl page
    When the user signs in from a header link carrying that huddl as the destination
    And the user enters "test+intent-header@example.com" in the email field
    And the user enters "Password123!" in the password field
    And the user submits the password sign in form
    Then the user is not asked what they came for
    And the user lands on the huddl "Moonlight loop"

  Scenario: The choice is not asked again on the next sign in
    Given a user exists with email "test+intent-once@example.com" and password "Password123!"
    And the user navigates to the sign in page
    When the user enters "test+intent-once@example.com" in the email field
    And the user enters "Password123!" in the password field
    And the user submits the password sign in form
    And the user chooses "Find a new one"
    And the user signs out
    And the user navigates to the sign in page
    And the user enters "test+intent-once@example.com" in the email field
    And the user enters "Password123!" in the password field
    And the user submits the password sign in form
    Then the user is not asked what they came for
    And the user lands on discover

  Scenario: The question can be skipped without answering it
    Given a user exists with email "test+intent-skip@example.com" and password "Password123!"
    And the user navigates to the sign in page
    When the user enters "test+intent-skip@example.com" in the email field
    And the user enters "Password123!" in the password field
    And the user submits the password sign in form
    Then the user is asked what they came for
    When the user skips the question
    Then the user lands on the agenda page
