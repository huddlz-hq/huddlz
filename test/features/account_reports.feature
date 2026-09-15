@database @conn @account_reports
Feature: Confirmed members report accounts to an administrator queue
  As a confirmed member
  I want to report an account I can already see
  So that an administrator can look into it without me running a case

  Background:
    Given the following users exist:
      | email                   | role  | display_name       |
      | admin589@example.com    | admin | Admin Alex         |
      | owner589@example.com    | user  | Owner Olive        |
      | spam589@example.com     | user  | Crypto Kings Promo |
      | member589@example.com   | user  | Member Maya        |
      | outsider589@example.com | user  | Outsider Omar      |
    And a public group "Portland Elixir" exists with owner "owner589@example.com"
    And "spam589@example.com" is an organizer of "Portland Elixir"
    And "member589@example.com" is a member of "Portland Elixir"
    And the huddl "Elixir Hack Night" exists in group "Portland Elixir" hosted by "owner589@example.com"
    And "spam589@example.com" has RSVPed to "Elixir Hack Night"
    And "member589@example.com" has RSVPed to "Elixir Hack Night"

  Scenario: A member reports an account from who's going
    Given I am signed in as "member589@example.com"
    When I visit the huddl page for "Elixir Hack Night"
    Then the menu for "Crypto Kings Promo" offers "Report account"
    When I choose "Report account" from the menu for "Crypto Kings Promo"
    And I confirm with "Report account"
    Then I should see "Say what's wrong: spam or advertising, or other."
    And there are no reports about "spam589@example.com"
    When I choose "Spam or advertising"
    And I fill in "Details" with "Posts coin listings in every thread"
    And I confirm with "Report account"
    Then I should see "Thanks—we've received your report."
    And "member589@example.com" has an open report about "spam589@example.com" for "spam" saying "Posts coin listings in every thread"
    And no email is sent about the report

  Scenario: Reporting again while a report is open adds nothing
    Given "member589@example.com" has reported "spam589@example.com" for "spam"
    And I am signed in as "member589@example.com"
    When I visit the group page for "Portland Elixir"
    And I choose "Report account" from the menu for "Crypto Kings Promo"
    And I choose "Other"
    And I confirm with "Report account"
    Then I should see "Thanks—we've received your report."
    And there is exactly 1 report about "spam589@example.com"
    When I report "spam589@example.com" through the API
    Then the report is accepted
    And there is exactly 1 report about "spam589@example.com"

  Scenario: The organizer roster offers reporting alongside membership actions
    Given I am signed in as "owner589@example.com"
    When I open the organizer roster for "Portland Elixir"
    Then the menu for "Crypto Kings Promo" offers "Demote to member"
    And the menu for "Crypto Kings Promo" offers "Report account"
    And there is no menu for "Owner Olive"

  Scenario: Only confirmed members who can already see the account may report it
    Given "member589@example.com" has not confirmed their address
    And I am signed in as "member589@example.com"
    When I visit the huddl page for "Elixir Hack Night"
    Then there is no menu for "Crypto Kings Promo"
    When I report "spam589@example.com" through the API
    Then the report is refused
    Given I am signed in as "outsider589@example.com"
    When I report "spam589@example.com" through the API
    Then the report is refused
    And there are no reports about "spam589@example.com"

  Scenario: Nobody reports themselves, and administrators use their own controls
    Given I am signed in as "member589@example.com"
    When I visit the huddl page for "Elixir Hack Night"
    Then there is no menu for "Member Maya"
    When I report "member589@example.com" through the API
    Then the report is refused
    Given "admin589@example.com" is a member of "Portland Elixir"
    And I am signed in as "admin589@example.com"
    When I visit the group page for "Portland Elixir"
    Then there is no menu for "Crypto Kings Promo"
