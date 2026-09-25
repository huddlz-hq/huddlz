@async @database @conn @map_links
Feature: Finding a huddl on a map
  As an attendee
  I want to open a huddl's physical location on a map
  So that I can find my way there

  Background:
    Given the following users exist:
      | email            | display_name | role    |
      | host@example.com | Host User    | regular |
    And a public group "Map Crew" exists with owner "host@example.com"

  Scenario: A visitor can find an in-person huddl on a map
    Given the in-person huddl "Meet nearby" in "Map Crew" is upcoming with 0 RSVPs
    When I visit the huddl "Meet nearby"
    Then I can view the huddl's physical location on Google Maps in a new tab

  Scenario: A visitor can find a hybrid huddl on a map
    Given the hybrid huddl "Join either way" in "Map Crew" is upcoming with 0 RSVPs
    When I visit the huddl "Join either way"
    Then I can view the huddl's physical location on Google Maps in a new tab

  Scenario: A virtual huddl does not offer a physical map
    Given the virtual huddl "Join online" in "Map Crew" is upcoming with 0 RSVPs
    When I visit the huddl "Join online"
    Then I should not see "View on map"
