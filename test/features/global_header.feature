@async @database @conn
Feature: Global Header
  As a visitor to the site
  I want a global header that pairs the brand with search and an organize entry point
  So that I can find huddlz from anywhere and start organizing without hunting through menus

  Scenario: Header chrome is visible on legacy pages
    Given the following users exist:
      | email                       | role |
      | header.user@example.com     | user |
    And a public group "Header Group" exists with owner "header.user@example.com"
    And I am signed in as "header.user@example.com"
    When I visit the edit page for "Header Group"
    Then the header should show the huddlz brand
    And the header should expose a global search form posting q to /discover
    And the header should expose an Organize link to /organize
    And the header should not expose a Groups link

  Scenario: V3 topbar exposes search posting to /discover
    When I visit "/discover"
    Then the v3 topbar should expose a search form posting q to /discover

  Scenario: Header search posts the query to /discover
    Given there are upcoming huddlz in the system
    When I visit "/discover?q=Elixir"
    Then I should see huddlz matching "Elixir"

  Scenario: Signed-in user sees the redesigned account menu on legacy pages
    Given the following users exist:
      | email                     | role |
      | menu.user@example.com     | user |
    And a public group "Menu Group" exists with owner "menu.user@example.com"
    And I am signed in as "menu.user@example.com"
    When I visit the edit page for "Menu Group"
    Then the account menu should expose the member, organizer, and account links
