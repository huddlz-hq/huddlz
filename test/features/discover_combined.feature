@async @database @conn
Feature: Combined search on /discover
  As a visitor browsing huddlz
  I want a single discover surface that can switch between huddlz and groups
  So that I can find either type of community without leaving the page

  Background:
    Given the following users exist:
      | email                               | role     | display_name |
      | host+discover-combined@example.com   | verified | Group Host   |
      | viewer+discover-combined@example.com | user     | Viewer       |

  Scenario: Default scope shows both scope chips
    When I visit "/discover"
    Then I should see "Huddlz"
    And I should see "Groups"

  Scenario: scope=groups shows the groups section
    Given a group named "Tampa Tech Talks" is owned by "host+discover-combined@example.com"
    When I visit "/discover?scope=groups"
    Then I should see "Browse groups"
    And I should see "Tampa Tech Talks"

  Scenario: scope=groups hides huddlz
    Given a group named "Tampa Tech Talks" is owned by "host+discover-combined@example.com"
    And the group "Tampa Tech Talks" has an upcoming huddl titled "Builders Night"
    When I visit "/discover?scope=groups"
    Then I should see "Tampa Tech Talks"
    And I should not see "Builders Night"

  Scenario: scope=groups empty state
    When I visit "/discover?scope=groups&q=zzznomatchforanything"
    Then I should see "No groups match this search"

  @group_distance
  Scenario: Discover groups within the chosen distance
    Given discover groups are based in Austin and Houston
    When I visit "/discover?scope=groups&location=Austin&lat=30.2672&lng=-97.7431&time_zone=America%2FChicago&distance=25"
    Then I should see "Austin Neighbors"
    And I should not see "Houston Neighbors"
    And I should see "25 mi"

  @group_distance
  Scenario: Changing the search location re-filters groups
    Given discover groups are based in Austin and Houston
    When I visit "/discover?scope=groups&location=Austin&lat=30.2672&lng=-97.7431&time_zone=America%2FChicago&distance=25"
    And I change the discover location to Houston
    Then I should see "Houston Neighbors"
    And I should not see "Austin Neighbors"

  @group_distance
  Scenario: Expanding the distance finds more groups
    Given discover groups are based in Austin and Houston
    When I visit "/discover?scope=groups&location=Central+Texas&lat=31.0&lng=-97.7431&time_zone=America%2FChicago&distance=25"
    Then I should see "No groups found"
    When I expand the discover distance to 100 miles
    Then I should see "Austin Neighbors"
    And I should not see "Houston Neighbors"
    And I should see "100 mi"

  @group_distance
  Scenario: Clearing a location filter recovers an empty group search
    Given discover groups are based in Austin and Houston
    When I visit "/discover?scope=groups&location=London&lat=51.5074&lng=-0.1278&time_zone=Europe%2FLondon&distance=25"
    Then I should see "No groups found"
    And I should see "Clear filters"
    When I click the "Clear filters" button
    Then I should see "Austin Neighbors"
    And I should see "Houston Neighbors"

  @group_distance
  Scenario: Group discovery defaults to the member's home search location
    Given discover groups are based in Austin and Houston
    And "viewer+discover-combined@example.com" has Austin as their home search location
    And I am logged in as "viewer+discover-combined@example.com"
    When I visit "/discover?scope=groups"
    Then I should see "Austin Neighbors"
    And I should not see "Houston Neighbors"
    And I should see "25 mi"
    When I click the "Clear filters" button
    Then I should see "Houston Neighbors"
