@sign_in_return_browser
Feature: Continuing after sign-in in a connected browser
  Scenario: Keep a group's Past page through header sign-in
    Given I am signed out on a public group's second Past page
    When I choose the header Sign in in a browser
    And I enter my return-visit credentials in a browser
    Then I see the same second Past page

  Scenario: Sign in when Help opens API keys without a page load
    Given I am signed out reading Help in a connected browser
    When I follow Help's API keys link
    And I enter my return-visit credentials in a browser
    Then I arrive at my API keys

  Scenario: Finish password recovery in the same browser
    Given I am signed out looking at a public huddl in a browser
    When I choose the header Sign in in a browser
    And I request and follow my password reset email in this browser
    And I set a new password for the return visit in a browser
    Then I return to that huddl without reserving a spot in a browser

  Scenario: Continue after a failed password and authentication detours
    Given I am signed out looking at a public huddl in a browser
    When I choose the header Sign in in a browser
    And I retry after a wrong password and the sign-up and recovery detours
    And I enter my return-visit credentials in a browser
    Then I return to that huddl without reserving a spot in a browser

  Scenario: Join attribution survives a group's contextual sign-in
    Given I am signed out on a public group's second Past page
    When I choose Sign in to join in a browser
    And I enter my return-visit credentials in a browser
    Then I see the same second Past page
    When I join the group after signing in
    Then my join retains its notification source

  Scenario: A reset email opened in a fresh browser keeps the normal home destination
    Given I am signed out looking at a public huddl in a browser
    When I choose the header Sign in in a browser
    And I request a password reset and open its email in a fresh browser
    And I set a new password for the return visit in a browser
    Then I arrive at my normal agenda after recovery
