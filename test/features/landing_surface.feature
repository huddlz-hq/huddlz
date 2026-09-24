@async @database @conn
Feature: Landing surface
  As a first-time visitor
  I want a clear pitch on the home page and a way to search straight away
  So that I can find a huddl worth showing up to before I sign up

  Background:
    Given the following users exist:
      | email                               | role     | display_name |
      | regular+landing-surface@example.com | verified | Regular User |

  Scenario: Anonymous visitor sees the pitch and CTAs
    When I visit "/"
    Then I should see "Stop scrolling."
    And I should see "showing up."
    And I should see "Find a huddl"
    And I should see "Browse huddlz"
    And I should see "Start a group"

  Scenario: Anonymous visitor sees how huddlz works
    When I visit "/"
    Then I should see "Find your thing"
    And I should see "RSVP in one tap"
    And I should see "Show up like a regular"
    And I should see "Bring your agent"
    And I should see "Run the huddl, not the spreadsheet."

  Scenario: Anonymous visitor sees sign-in and sign-up links in the topbar
    When I visit "/"
    Then I should see "Sign in"
    And I should see "Sign up"

  Scenario: Visitor sees the sample huddlz marked as examples
    When I visit "/"
    Then I should see "Example week"
    And I should see "Example chat"

  Scenario: Visitor searches for huddlz from the landing page
    Given there are upcoming huddlz in the system
    When I visit "/"
    And I fill in "Into" with "Elixir"
    And I click the "Find a huddl" button
    Then I should see huddlz matching "Elixir"

  Scenario: Visitor narrows the landing search to a place
    When I visit "/"
    And I type "aus" in the location field
    And I select "Austin" from the location suggestions
    And I click the "Find a huddl" button
    Then the location filter should be active with "Austin, TX, USA"

  Scenario: A landing search waits for the picked place before opening Discover
    When I visit "/"
    And I type "aus" in the location field
    And I pick "Austin" from the location suggestions while its details are still loading
    And I click the "Find a huddl" button
    Then the search waits for the place
    When the place details arrive
    Then Discover opens searching near "Austin, TX, USA"

  Scenario: A failed place lookup leaves Near empty
    When I visit "/"
    And I type "aus" in the location field
    And I pick "Austin" from the location suggestions while its details are still loading
    And the place lookup fails
    Then the location filter should not be active
    And I should see "Location search is currently unavailable"
    When I click the "Find a huddl" button
    Then Discover searches without a place

  Scenario: Clearing Near while the place is loading keeps it out of the search
    When I visit "/"
    And I type "aus" in the location field
    And I pick "Austin" from the location suggestions while its details are still loading
    And I clear the selected location
    And the cleared place's lookup finishes
    And I click the "Find a huddl" button
    Then Discover searches without a place

  Scenario: Editing Near while the place is loading keeps it out of the search
    When I visit "/"
    And I type "aus" in the location field
    And I pick "Austin" from the location suggestions while its details are still loading
    And I reopen Near and erase the place
    And I click the "Find a huddl" button
    Then Discover searches without a place

  Scenario: Erasing a picked place keeps it out of the search
    When I visit "/"
    And I type "aus" in the location field
    And I select "Austin" from the location suggestions
    And I reopen Near and erase the place
    And I click the "Find a huddl" button
    Then Discover searches without a place

  Scenario: Visitor picks an interest from the landing page
    When I visit "/"
    And I click link "Board games"
    Then I should see "Results for “Board games”" as the page heading

  Scenario: Authenticated user is redirected from / to /agenda
    Given I am signed in as "regular+landing-surface@example.com"
    When I visit "/"
    Then I should see "Agenda"
    And I should see "What's next"
