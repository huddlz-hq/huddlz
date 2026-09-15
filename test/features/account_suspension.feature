@database @conn @account_suspension
Feature: Administrators suspend abusive accounts and restore mistaken suspensions
  As an administrator
  I want to suspend an abusive account with a reason
  So that the person loses access and exposure while the community keeps its records

  Background:
    Given the following users exist:
      | email                 | role  | display_name       |
      | admin587@example.com  | admin | Admin Alex         |
      | other587@example.com  | admin | Admin Avery        |
      | owner587@example.com  | user  | Owner Olive        |
      | spam587@example.com   | user  | Crypto Kings Promo |
      | member587@example.com | user  | Member Maya        |
    And a public group "Portland Elixir" exists with owner "owner587@example.com"
    And "spam587@example.com" is an organizer of "Portland Elixir"
    And "member587@example.com" is an organizer of "Portland Elixir"

  Scenario: An administrator suspends an account with a reason
    Given I am signed in as "admin587@example.com"
    When I visit "/admin/users"
    Then "Crypto Kings Promo" is listed under "People"
    And the menu for "Crypto Kings Promo" offers "Suspend account"
    When I choose "Suspend account" from the menu for "Crypto Kings Promo"
    And I confirm with "Suspend account"
    Then I should see "Say why"
    And "spam587@example.com" is not suspended
    When I fill in "Reason" with "Repeated coin listings"
    And I confirm with "Suspend account"
    Then I should see "Crypto Kings Promo is suspended"
    And "Crypto Kings Promo" is not listed among the accounts
    And the suspension of "spam587@example.com" records "admin587@example.com" and the reason "Repeated coin listings"
    When I click "Suspended"
    Then "Crypto Kings Promo" is listed under "Suspended"
    And I should see "Repeated coin listings"
    And I should see "by Admin Alex"

  Scenario: Only administrators can suspend or restore
    Given I am signed in as "owner587@example.com"
    When I try to suspend "spam587@example.com" through the API
    Then the suspension is refused
    And "spam587@example.com" is not suspended
    When "admin587@example.com" suspends "spam587@example.com" for "Spam"
    And I try to restore "spam587@example.com" through the API
    Then the restoration is refused
    And "spam587@example.com" is suspended

  Scenario: Suspension ends the person's access everywhere at once
    Given the user "spam587@example.com" has password "Password123!"
    And "spam587@example.com" is signed in on another device
    And "spam587@example.com" has an API key
    When "admin587@example.com" suspends "spam587@example.com" for "Spam"
    Then the other device is signed out with "This account is suspended"
    And the API key of "spam587@example.com" is rejected
    And "spam587@example.com" cannot sign in with password "Password123!"
    But the public group page for "Portland Elixir" is still open to browse

  @suspension_socket
  Scenario: Suspension ends access on an already connected API client
    Given "spam587@example.com" has an open authenticated API connection
    When "admin587@example.com" suspends "spam587@example.com" for "Spam"
    Then the open API connection can no longer read the person's account

  Scenario: A password reset does not lift a suspension
    Given the user "spam587@example.com" has password "Password123!"
    And "admin587@example.com" suspends "spam587@example.com" for "Spam"
    When "spam587@example.com" resets their password to "NewPassword456!"
    Then I should see "This account is suspended"
    And I should not be signed in
    And "spam587@example.com" cannot sign in with password "NewPassword456!"

  Scenario: Confirming an email address does not lift a suspension
    Given "spam587@example.com" has not confirmed their address
    And "spam587@example.com" asks for the confirmation email again
    And "admin587@example.com" suspends "spam587@example.com" for "Spam"
    When I visit "/"
    And I open the confirmation link sent to "spam587@example.com"
    Then the page tells me the link no longer works and offers to sign in
    And I should not be signed in
    And "spam587@example.com" is still unconfirmed

  Scenario: A suspended account disappears from member lists and who's going
    Given the huddl "Elixir Hack Night" exists in group "Portland Elixir" hosted by "owner587@example.com"
    And "spam587@example.com" has RSVPed to "Elixir Hack Night"
    And "member587@example.com" has RSVPed to "Elixir Hack Night"
    And "admin587@example.com" suspends "spam587@example.com" for "Spam"
    Given I am signed in as "owner587@example.com"
    When I open the organizer roster for "Portland Elixir"
    Then I should see "2 people"
    And I should not see "Crypto Kings Promo"
    When I visit the group page for "Portland Elixir"
    Then I should not see "Crypto Kings Promo"
    Given I am signed in as "member587@example.com"
    When I visit the huddl page for "Elixir Hack Night"
    Then I should see "Member Maya"
    And I should not see "Crypto Kings Promo"
    And the API members of "Portland Elixir" do not include "Crypto Kings Promo"
    And the API people going to "Elixir Hack Night" do not include "Crypto Kings Promo"

  Scenario: Records that must keep their author show a neutral label
    Given the past huddl "Coin Listing Party" exists in group "Portland Elixir" hosted by "spam587@example.com"
    And "spam587@example.com" attended "Coin Listing Party"
    And "member587@example.com" attended "Coin Listing Party"
    When "admin587@example.com" suspends "spam587@example.com" for "Spam"
    Given I am signed in as "member587@example.com"
    When I visit the huddl page for "Coin Listing Party"
    Then I should see "Suspended account"
    And I should not see "Crypto Kings Promo"
    And the people going to "Coin Listing Party" read through the API include "Suspended account" but not "Crypto Kings Promo"
    Given I am signed in as "owner587@example.com"
    When I visit "/organize/portland-elixir"
    Then the feed shows "Suspended account RSVPd to Coin Listing Party"
    And the feed does not show "Crypto Kings Promo RSVPd to Coin Listing Party"

  Scenario: Suspension releases upcoming spots and lets the waitlist move
    Given the huddl "Full House" exists in group "Portland Elixir" hosted by "spam587@example.com"
    And "Full House" has room for 1 people
    And "member587@example.com" is on the waitlist for "Full House"
    When "admin587@example.com" suspends "spam587@example.com" for "Spam"
    Then "member587@example.com" is confirmed for "Full House"
    And "spam587@example.com" is no longer attending "Full House"
    And the RSVP by "spam587@example.com" to "Full House" is still on record

  Scenario: A suspended person on a waitlist is never promoted
    Given the huddl "Tight Squeeze" exists in group "Portland Elixir" hosted by "member587@example.com"
    And "Tight Squeeze" has room for 1 people
    And "spam587@example.com" is on the waitlist for "Tight Squeeze"
    And "owner587@example.com" is on the waitlist for "Tight Squeeze"
    When "admin587@example.com" suspends "spam587@example.com" for "Spam"
    And "member587@example.com" cancels the RSVP to "Tight Squeeze"
    Then "owner587@example.com" is confirmed for "Tight Squeeze"
    And "spam587@example.com" is no longer attending "Tight Squeeze"

  @suspension_huddl_review
  Scenario: Owned groups and upcoming huddlz stay and are flagged for review
    Given a public group "Crypto Kings PDX" exists with owner "spam587@example.com"
    And the huddl "Coin Launch" exists in group "Crypto Kings PDX" hosted by "spam587@example.com"
    And the huddl "Guest Coin Talk" exists in group "Portland Elixir" hosted by "spam587@example.com"
    When "admin587@example.com" suspends "spam587@example.com" for "Spam"
    Given I am signed in as "admin587@example.com"
    When I visit "/admin/users"
    And I click "Suspended"
    And I click "Review"
    Then I should see "Crypto Kings PDX"
    And I should see "Needs a look"
    And I should see "Coin Launch"
    And I should see "Guest Coin Talk"
    When I visit the group page for "Crypto Kings PDX"
    Then I should see "Coin Launch"
    And I should not see "Edit Group"

  @suspension_private_review
  Scenario: Account review respects private group permissions
    Given a private group "Quiet Circle" exists with owner "spam587@example.com"
    And the huddl "Private Conversation" exists in group "Quiet Circle" hosted by "spam587@example.com"
    And "admin587@example.com" suspends "spam587@example.com" for "Spam"
    And I am signed in as "admin587@example.com"
    When I visit "/admin/users?scope=suspended"
    And I click "Review"
    Then I should not see "Quiet Circle"
    And I should not see "Private Conversation"
    And I should see "Only groups you can normally access are shown."

  @suspension_private_review
  Scenario: Account review keeps the administrator's ordinary organizer access
    Given a private group "Quiet Circle" exists with owner "spam587@example.com"
    And "admin587@example.com" is an organizer of "Quiet Circle"
    And the huddl "Private Conversation" exists in group "Quiet Circle" hosted by "spam587@example.com"
    And "admin587@example.com" suspends "spam587@example.com" for "Spam"
    And I am signed in as "admin587@example.com"
    When I visit "/admin/users?scope=suspended"
    And I click "Review"
    Then I should see "Quiet Circle"
    And I should see "Private Conversation"

  @suspension_notification_names
  Scenario: Pending email and the inbox hide a suspended person's old name
    Given the huddl "Elixir Hack Night" exists in group "Portland Elixir" hosted by "owner587@example.com"
    And "spam587@example.com" has RSVPed to "Elixir Hack Night"
    And I am signed in as "owner587@example.com"
    When I visit "/notifications"
    Then I should see "Crypto Kings Promo RSVPed to Elixir Hack Night"
    When "admin587@example.com" suspends "spam587@example.com" for "Spam"
    And pending notification email is delivered
    Then the RSVP email to "owner587@example.com" for "Elixir Hack Night" names "Suspended account" instead of "Crypto Kings Promo"
    When I visit "/notifications"
    Then I should see "Suspended account RSVPed to Elixir Hack Night"
    And I should not see "Crypto Kings Promo"

  @suspension_legacy_notification
  Scenario: Older notifications do not expose names that cannot be safely attributed
    Given an older RSVP notification names "Crypto Kings Promo" to "owner587@example.com" for "Elixir Hack Night"
    When "admin587@example.com" suspends "spam587@example.com" for "Spam"
    And pending notification email is delivered
    Then the RSVP email to "owner587@example.com" for "Elixir Hack Night" names "Someone" instead of "Crypto Kings Promo"
    Given I am signed in as "owner587@example.com"
    When I visit "/notifications"
    Then I should see "Someone RSVPed to Elixir Hack Night"
    And I should not see "Crypto Kings Promo"

  Scenario: The person gets one plain notice and no further community email
    When "admin587@example.com" suspends "spam587@example.com" for "Two member reports"
    Then a suspension notice is sent to "spam587@example.com" with the support address
    And the notice does not mention "Two member reports"
    When "owner587@example.com" announces the huddl "After the Fact" in "Portland Elixir"
    Then no huddl announcement is sent to "spam587@example.com"
    But a huddl announcement is sent to "member587@example.com"

  Scenario: Restoration is manual and brings back sign-in without reviving what was revoked
    Given the user "spam587@example.com" has password "Password123!"
    And "spam587@example.com" is signed in on another device
    And the huddl "Full House" exists in group "Portland Elixir" hosted by "spam587@example.com"
    And "Full House" has room for 1 people
    And "member587@example.com" is on the waitlist for "Full House"
    And "admin587@example.com" suspends "spam587@example.com" for "Mistaken report"
    And I am signed in as "admin587@example.com"
    When I visit "/admin/users"
    And I click "Suspended"
    And I choose "Restore account" from the menu for "Crypto Kings Promo"
    And I confirm with "Restore account"
    Then I should see "Crypto Kings Promo is restored"
    And "spam587@example.com" is not suspended
    When I click "Accounts"
    Then "Crypto Kings Promo" is listed under "People"
    And the other device is still signed out
    And "spam587@example.com" can sign in with password "Password123!"
    And "member587@example.com" is confirmed for "Full House"
    And "spam587@example.com" is no longer attending "Full House"

  Scenario: Administrators cannot suspend themselves or each other
    Given I am signed in as "admin587@example.com"
    When I visit "/admin/users"
    Then there is no menu for "Admin Alex"
    And the menu for "Admin Avery" does not offer "Suspend account"
