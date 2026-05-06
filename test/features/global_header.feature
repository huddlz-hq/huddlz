@async @database @conn
Feature: Global Header
  As a visitor to the site
  I want a global header that pairs the brand with search and an organize entry point
  So that I can find huddlz from anywhere and start organizing without hunting through menus

  Scenario: Header chrome is visible on the home page
    Given the user is on the home page
    Then the header should show the huddlz brand
    And the header should expose a global search form posting q to /discover
    And the header should expose an Organize link to /groups/new
    And the header should not expose a Groups link

  Scenario: Header search posts the query to /discover
    Given there are upcoming huddlz in the system
    When I visit "/discover?q=Elixir"
    Then I should see huddlz matching "Elixir"

  Scenario: Signed-in user sees the redesigned account menu
    Given I am signed in as "menu.user@example.com" with password "Password123!"
    Then the account menu should expose the member, organizer, and account links
