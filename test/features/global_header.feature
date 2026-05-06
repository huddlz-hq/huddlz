@async @database @conn
Feature: Global Header
  As a visitor to the site
  I want a global header that pairs the brand with search and an organize entry point
  So that I can find huddlz from anywhere and start organizing without hunting through menus

  Scenario: Header chrome is visible on the home page
    Given the user is on the home page
    Then the header should show the huddlz brand
    And the header should expose a global search form posting q to the home page
    And the header should expose an Organize link to /groups/new
    And the header should not expose a Groups link

  Scenario: Header search posts the query to the home page
    Given there are upcoming huddlz in the system
    When I visit "/?q=Elixir"
    Then I should see huddlz matching "Elixir"
