@async @database @conn @header_return_to
Feature: Signing in from the header returns to where I was
  As a person who arrived from a link or a QR code with one huddl in mind
  I want the header's sign-in to bring me back to that huddl
  So that signing in does not cost me the page I came for

  Background:
    Given the following users exist:
      | email              | role | display_name |
      | host@example.com   | user | Host         |
      | guest@example.com  | user | Guest        |
    And the following group exists:
      | name         | description   | is_public | owner_email      |
      | Trail Pals   | We walk a lot | true      | host@example.com |
    And the following huddl exists in "Trail Pals":
      | title       | description  | event_type | starts_at    | virtual_link           |
      | Dawn Walk   | Early start  | virtual    | tomorrow 2pm | https://meet.example/a |
    And the user "guest@example.com" has password "Password123!"

  Scenario: The header sign-in returns me to the huddl I was reading
    Given I start in a signed-out browser
    When I visit the "Dawn Walk" huddl page while signed out
    And I choose "Sign in" in the site header
    And I sign in as "guest@example.com" with password "Password123!"
    Then I should be on the huddl page for "Dawn Walk"
    And I should see "RSVP to this huddl"

  Scenario: The header sign-in returns me to the group I was reading
    Given I start in a signed-out browser
    When I visit "/groups/trail-pals"
    And I choose "Sign in" in the site header
    And I sign in as "guest@example.com" with password "Password123!"
    Then I should see "Trail Pals"
    And I should see "Join Group"

  Scenario: The header sign-up returns me to the huddl after confirming
    Given I start in a signed-out browser
    When I visit the "Dawn Walk" huddl page while signed out
    And I choose "Sign up" in the site header
    And I complete registration as "newcomer@example.com"
    Then I should be on the huddl page for "Dawn Walk"
    And I should see "Confirm your email before you RSVP"
    When I confirm the email for "newcomer@example.com" in another browser
    Then I should be on the huddl page for "Dawn Walk"
    And I should see "RSVP to this huddl"

  Scenario: A tagged arrival keeps its source through the header sign-in
    Given I start in a signed-out browser
    When I arrive at "/groups/trail-pals?from=notification"
    And I choose "Sign in" in the site header
    And I sign in as "guest@example.com" with password "Password123!"
    Then I should see "Trail Pals"
    And I should see "Join Group"

  Scenario: An unsafe return destination cannot redirect the header sign-in
    When unsafe header return destinations are offered:
      | destination                       |
      | https://evil.example/groups/x     |
      | //evil.example/groups/x           |
      | /groups/%2f%2fevil.example        |
      | \\evil.example                    |
      | evil.example/groups/x             |
    Then each unsafe header return destination is refused
