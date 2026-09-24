@async @database @conn @copy_huddl_api
Feature: Copy a huddl through the API
  As an organizer using an API client
  I want to create a huddl from another huddl of my group
  So that I can run the same gathering again without retyping it

  Scenario Outline: Copying a past huddl onto a new date
    Given I organize a group with a past huddl "Hands-on with Ash Framework"
    When I copy it through "<api>" on a future date
    Then the copy has the original's title, description, format, location, online link, capacity and visibility
    And the copy starts at the original's local time on the new date and lasts as long

    Examples:
      | api      |
      | JSON:API |
      | GraphQL  |

  Scenario: What I supply replaces the copied value
    Given I organize a group with a past huddl "Hands-on with Ash Framework"
    When I copy it through "JSON:API" on a future date titled "Ash, round two"
    Then the copy is titled "Ash, round two"
    And the copy has the original's description

  Scenario: Only the organizer who copied is going
    Given I organize a group with a past huddl "Hands-on with Ash Framework"
    And people RSVPd to that huddl, shared a photo and a turnout was recorded
    When I copy it through "JSON:API" on a future date
    Then I am the only person going to the copy
    And the copy has no photos and no turnout

  Scenario: The cover comes along as its own image
    Given I organize a group with a past huddl "Hands-on with Ash Framework"
    And that huddl has a cover image
    When I copy it through "JSON:API" on a future date
    Then the copy has its own copy of the cover image
    When I remove the copy's cover image
    Then the original still has its cover image

  Scenario: A copy of a series huddl is a one-off
    Given I organize a group with a weekly series "Elixir study night"
    When I copy it through "JSON:API" on a future date
    Then the copy is not part of any series

  Scenario: Copying a cancelled huddl
    Given I organize a group with a cancelled huddl "LiveView patterns in practice"
    When I copy it through "JSON:API" on a future date
    Then the copy is scheduled

  Scenario: A copy needs a date
    Given I organize a group with a past huddl "Hands-on with Ash Framework"
    When I copy it through "JSON:API" without a date
    Then the copy is refused because "date" "is required when copying a huddl"

  Scenario: The date must be in the future
    Given I organize a group with a past huddl "Hands-on with Ash Framework"
    When I copy it through "JSON:API" on a past date
    Then the copy is refused because "date" "must be in the future"

  Scenario: The original's location was removed
    Given I organize a group with a past huddl "Hands-on with Ash Framework"
    And its location was removed from the address book
    When I copy it through "JSON:API" on a future date
    Then the copy is refused because "group_location_id" "was removed from the address book"

  Scenario: Choosing a location when the original's was removed
    Given I organize a group with a past huddl "Hands-on with Ash Framework"
    And its location was removed from the address book
    When I copy it through "JSON:API" on a future date at "Ecotrust Building"
    Then the copy meets at "Ecotrust Building"

  Scenario: Only organizers of the group can copy
    Given a group I belong to as a member has a past huddl "Hands-on with Ash Framework"
    When I copy it through "JSON:API" on a future date
    Then the copy is forbidden

  Scenario: A copy stays in its group
    Given I organize a group with a past huddl "Hands-on with Ash Framework"
    And I organize another group
    When I copy it into the other group through "JSON:API"
    Then the copy is refused because "group_id" "must be the copied huddl's group"

  Scenario: The history records the copy
    Given I organize a group with a past huddl "Hands-on with Ash Framework"
    When I copy it through "JSON:API" on a future date
    Then the copy's history records that it was copied from the original

  Scenario Outline: Copying a draft in a private group
    Given I organize a private group with a draft huddl "Hands-on with Ash Framework"
    When I copy it through "<api>" on a future date
    Then the copy has the original's title, description, format, location, online link, capacity and visibility

    Examples:
      | api      |
      | JSON:API |
      | GraphQL  |

  Scenario: Copying onto a start time keeps the original's length
    Given I organize a group with a past huddl "Hands-on with Ash Framework"
    When I copy it through "JSON:API" starting at a future time
    Then the copy starts at that time and lasts as long as the original

  Scenario: A copy cannot start in the past
    Given I organize a group with a past huddl "Hands-on with Ash Framework"
    When I copy it through "JSON:API" starting and ending at past times
    Then the copy is refused because "starts_at" "must be in the future"
