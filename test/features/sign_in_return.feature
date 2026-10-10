@async @database @conn @sign_in_return
Feature: Returning after sign-in
  People can continue where they chose to sign in without searching for the page again.

  Scenario: Sign in from a huddl's header
    Given I am signed out looking at a public huddl for a return visit
    When I choose Sign in from the page header
    And I sign in for the return visit
    Then I return to that huddl without reserving a spot

  Scenario: Keep a group's Past page through header sign-in
    Given I am signed out looking at a public group's Past huddlz for a return visit
    When I choose Sign in from the page header
    And I sign in for the return visit
    Then I return to the group's Past huddlz

  Scenario: Keep a saved Discover search through header sign-in
    Given I am signed out looking at a public huddl for a return visit
    When I open my saved Discover search for the return visit
    And I choose Sign in from the page header
    And I sign in for the return visit
    Then I return to the same Discover search

  Scenario: Keep an account-only saved Discover search through sign-in
    Given I am signed out looking at a public huddl for a return visit
    When I open my saved attending search for the return visit
    And I sign in for the return visit
    Then I return to the same attending search

  Scenario: Return to an email-change page after header sign-in
    Given I am signed out looking at a public huddl for a return visit
    When I open an expired email-change link for the return visit
    And I choose Sign in from the page header
    And I sign in for the return visit
    Then I return to the email-change page

  Scenario: Keep the destination after a wrong password and detours
    Given I am signed out looking at a public huddl for a return visit
    When I choose Sign in from the page header
    And I sign in with the wrong password for the return visit
    And I click link "Sign up"
    And I click link "Sign in"
    And I click link "Forgot your password?"
    And I click link "Back to sign in"
    And I sign in for the return visit
    Then I return to that huddl without reserving a spot

  Scenario: An unsafe return destination cannot redirect sign-in
    Given I am signed out looking at a public huddl for a return visit
    When I visit "/sign-in?return_to=%2F%2Fevil.example"
    And I sign in for the return visit
    Then I land on my agenda instead
