@global_header @async @database @conn
Feature: Global Header
  As a visitor to the site
  I want a global header that pairs the brand with search and an organize entry point
  So that I can find huddlz from anywhere and start organizing without hunting through menus

  Scenario: V3 topbar exposes search posting to /discover
    When I visit "/discover"
    Then the v3 topbar should expose a search form posting q to /discover

  Scenario: Header search submits the query to Discover from an application page
    Given I am signed in
    And I am viewing Calendar
    When I use the global Discover search
    Then Discover shows the submitted "coffee" query
