@async @database @conn @huddl_organizer_moderation
Feature: Report or block a huddl's organizer from the huddl
  As a person browsing huddlz in an app that never shows who organized them
  I want to report or block the organizer of a huddl I can see
  So that I can raise a concern and stop seeing their huddlz

  Background:
    Given the following users exist:
      | email                 | role | display_name       |
      | owner612@example.com  | user | Owner Olive        |
      | spam612@example.com   | user | Crypto Kings Promo |
      | member612@example.com | user | Member Maya        |
    And a public group "Moderation Brooklyn Coffee" exists with owner "owner612@example.com"
    And "spam612@example.com" is an organizer of "Moderation Brooklyn Coffee"
    And the huddl "Free Coin Giveaway" exists in group "Moderation Brooklyn Coffee" hosted by "spam612@example.com"
    And the huddl "Saturday Pour Over" exists in group "Moderation Brooklyn Coffee" hosted by "owner612@example.com"

  Scenario: A member reports a huddl's organizer without learning who they are
    Given I am signed in as "member612@example.com"
    When I report the organizer of "Free Coin Giveaway" for "spam" saying "Coin listings" through JSON:API
    Then the organizer report is accepted without naming the organizer
    And "member612@example.com" has an open report about "spam612@example.com" for "spam" saying "Coin listings"
    And the report about "spam612@example.com" came from the huddl "Free Coin Giveaway"

  Scenario: Reporting an organizer follows the rules for reporting an account
    Given I am signed in as "member612@example.com"
    When I report the organizer of "Free Coin Giveaway" for "" saying "" through JSON:API
    Then JSON:API asks for an organizer report reason
    Given I am signed in as "spam612@example.com"
    When I report the organizer of "Free Coin Giveaway" for "spam" saying "" through JSON:API
    Then the organizer report is refused
    Given "member612@example.com" has not confirmed their address
    And I am signed in as "member612@example.com"
    When I report the organizer of "Free Coin Giveaway" for "spam" saying "" through JSON:API
    Then the organizer report is refused
    And there are no reports about "spam612@example.com"

  Scenario: Visitors cannot report or block an organizer
    When I report the organizer of "Free Coin Giveaway" for "spam" saying "" through JSON:API
    Then the organizer report is refused
    When I block the organizer of "Free Coin Giveaway" through JSON:API
    Then the block is refused
    And there are no reports about "spam612@example.com"

  Scenario: Blocking an organizer hides their huddlz from discovery and the group
    Given I am signed in as "member612@example.com"
    When I block the organizer of "Free Coin Giveaway" through JSON:API
    Then the block is accepted
    And discovery through JSON:API shows "Saturday Pour Over"
    But discovery through JSON:API does not show "Free Coin Giveaway"
    And the group's upcoming huddlz through JSON:API do not show "Free Coin Giveaway"
    And I can still open "Free Coin Giveaway" through JSON:API

  Scenario: Blocking again keeps a single block
    Given I am signed in as "member612@example.com"
    When I block the organizer of "Free Coin Giveaway" through JSON:API
    And I block the organizer of "Free Coin Giveaway" through JSON:API
    Then the block is accepted
    And my blocked people through JSON:API are "Crypto Kings Promo"

  Scenario: Unblocking brings an organizer's huddlz back
    Given I am signed in as "member612@example.com"
    And I block the organizer of "Free Coin Giveaway" through JSON:API
    When I unblock "Crypto Kings Promo" through JSON:API
    Then my blocked people through JSON:API are ""
    And discovery through JSON:API shows "Free Coin Giveaway"

  Scenario: A block is private to the person who made it
    Given "member612@example.com" has blocked the organizer of "Free Coin Giveaway"
    And I am signed in as "spam612@example.com"
    Then my blocked people through JSON:API are ""
    And discovery through JSON:API shows "Free Coin Giveaway"
    When I try to remove the block "member612@example.com" made through JSON:API
    Then "member612@example.com" still blocks "spam612@example.com"

  Scenario: Nobody blocks themselves
    Given I am signed in as "spam612@example.com"
    When I block the organizer of "Free Coin Giveaway" through JSON:API
    Then the block is turned down with "You organize this huddl."

  Scenario: A huddl tells its organizer that they organized it
    Given I am signed in as "spam612@example.com"
    Then JSON:API says I organized "Free Coin Giveaway"
    And JSON:API says I did not organize "Saturday Pour Over"
    Given I am signed in as "member612@example.com"
    Then JSON:API says I did not organize "Free Coin Giveaway"
