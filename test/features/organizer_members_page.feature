@async @database @conn @organizer_members_page
Feature: Organizer members page
  Organizers scan the roster by role and manage each person from one menu.

  Background:
    Given the following users exist:
      | email                 | role | display_name    |
      | owner552@example.com  | user | Owner Olive     |
      | helper552@example.com | user | Organizer Oscar |
      | member552@example.com | user | Member Maya     |
    And a public group "Roster Redesign" exists with owner "owner552@example.com"
    And "helper552@example.com" is an organizer of "Roster Redesign"
    And "member552@example.com" is a member of "Roster Redesign"

  Scenario: The roster reads as people grouped by role
    Given I am signed in as "owner552@example.com"
    When I open the organizer roster for "Roster Redesign"
    Then I should see "3 people"
    And "Owner Olive" is listed under "Owner"
    And "Organizer Oscar" is listed under "Organizers"
    And "Member Maya" is listed under "Members"

  Scenario: Membership actions sit behind a per-person menu
    Given I am signed in as "owner552@example.com"
    When I open the organizer roster for "Roster Redesign"
    Then the menu for "Member Maya" offers "Promote to organizer"
    And the menu for "Member Maya" offers "Remove from group"
    And the menu for "Organizer Oscar" offers "Demote to member"
    And there is no menu for "Owner Olive"

  Scenario: An organizer's menu offers only what they may do
    Given I am signed in as "helper552@example.com"
    When I open the organizer roster for "Roster Redesign"
    Then the menu for "Member Maya" offers "Remove from group"
    And the menu for "Member Maya" does not offer "Promote to organizer"
    And there is no menu for "Organizer Oscar"

  Scenario: Promoting from the menu moves the person to Organizers
    Given I am signed in as "owner552@example.com"
    When I open the organizer roster for "Roster Redesign"
    And I choose "Promote to organizer" from the menu for "Member Maya"
    And I confirm with "Promote to organizer"
    Then "Member Maya" is listed under "Organizers"
