@async @database @conn
Feature: Global Header
  As a visitor to the site
  I want a global header that pairs the brand with search and an organize entry point
  So that I can find huddlz from anywhere and start organizing without hunting through menus

  Scenario: V3 topbar exposes search posting to /discover
    When I visit "/discover"
    Then the v3 topbar should expose a search form posting q to /discover

  Scenario: Header search posts the query to /discover
    Given there are upcoming huddlz in the system
    When I visit "/discover?q=Elixir"
    Then I should see huddlz matching "Elixir"
