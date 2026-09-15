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

  @dashboard_administration @json_account_reports
  Scenario: Account administration is available through the dashboard only
    Given I am signed in as "admin589@example.com"
    Then the API offers member reporting without account administration
    And JSON:API offers report submission without administration

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

  @json_account_reports
  Scenario: A member submits a report through JSON:API and retries through either API
    Given I am signed in as "member589@example.com"
    When I report "spam589@example.com" for "other" saying "Repeated advertising" through JSON:API
    Then the JSON:API report is accepted
    And "member589@example.com" has an open report about "spam589@example.com" for "other" saying "Repeated advertising"
    Given I use an API key to submit reports
    When I report "spam589@example.com" for "spam" saying "A retry" through JSON:API
    Then the JSON:API report is accepted
    When I report "spam589@example.com" through the API
    Then the report is accepted
    And there is exactly 1 report about "spam589@example.com"
    And "member589@example.com" has an open report about "spam589@example.com" for "other" saying "Repeated advertising"
    And no email is sent about the report

  @json_account_reports
  Scenario: JSON:API requires a reason but details are optional
    Given I am signed in as "member589@example.com"
    When I report "spam589@example.com" for "" saying "" through JSON:API
    Then JSON:API asks for a report reason
    And there are no reports about "spam589@example.com"
    When I report "spam589@example.com" for "spam" saying "" through JSON:API
    Then the JSON:API report is accepted
    And there is exactly 1 report about "spam589@example.com"

  @json_account_reports
  Scenario: Visitors cannot submit reports through JSON:API
    When I report "spam589@example.com" for "spam" saying "" through JSON:API
    Then the JSON:API report is refused
    And there are no reports about "spam589@example.com"

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

  @json_account_reports
  Scenario: Only confirmed members who can already see the account may report it
    Given "member589@example.com" has not confirmed their address
    And I am signed in as "member589@example.com"
    When I visit the huddl page for "Elixir Hack Night"
    Then there is no menu for "Crypto Kings Promo"
    When I report "spam589@example.com" through the API
    Then the report is refused
    When I report "spam589@example.com" for "spam" saying "" through JSON:API
    Then the JSON:API report is refused
    Given I am signed in as "outsider589@example.com"
    When I report "spam589@example.com" through the API
    Then the report is refused
    When I report "spam589@example.com" for "spam" saying "" through JSON:API
    Then the JSON:API report is refused
    And there are no reports about "spam589@example.com"

  @json_account_reports
  Scenario: Nobody reports themselves, and administrators use their own controls
    Given I am signed in as "member589@example.com"
    When I visit the huddl page for "Elixir Hack Night"
    Then there is no menu for "Member Maya"
    When I report "member589@example.com" through the API
    Then the report is refused
    When I report "member589@example.com" for "spam" saying "" through JSON:API
    Then the JSON:API report is refused
    Given "admin589@example.com" is a member of "Portland Elixir"
    And I am signed in as "admin589@example.com"
    When I visit the group page for "Portland Elixir"
    Then there is no menu for "Crypto Kings Promo"

  Scenario: Reports are for administrators only and never reach the reported person
    Given "member589@example.com" has reported "spam589@example.com" for "spam" saying "Posts coin listings in every thread"
    And I am signed in as "spam589@example.com"
    When I read the reports through the API
    Then no reports are returned
    When I visit "/notifications"
    Then I should not see "report"
    And "spam589@example.com" is not suspended
    Given I am signed in as "owner589@example.com"
    When I read the reports through the API
    Then no reports are returned
    When I visit "/admin/reports"
    Then I should not see "Posts coin listings in every thread"

  Scenario: An administrator reviews a report, suspends the account and marks the report handled
    Given "member589@example.com" has reported "spam589@example.com" for "spam" saying "Posts coin listings in every thread" from the huddl "Elixir Hack Night"
    And I am signed in as "admin589@example.com"
    When I visit "/admin/reports"
    Then "Crypto Kings Promo" is listed under "Open"
    And I should see "Spam or advertising"
    And I should see "Member Maya"
    When I click "Review"
    Then I should see "Posts coin listings in every thread"
    And I should see "Elixir Hack Night"
    When I click "Suspend account" in the review card
    And I fill in "Reason" with "Two member reports"
    And I confirm with "Suspend account"
    Then I should see "Crypto Kings Promo is suspended"
    And "spam589@example.com" is suspended
    And "Crypto Kings Promo" is listed under "Open"
    And I should see "Suspended"
    And I should not see "Suspend account"
    When I choose "Mark handled" from the menu for "Crypto Kings Promo"
    Then I should see "Report handled"
    And the report about "spam589@example.com" is handled by "admin589@example.com"
    When I click "Handled"
    Then "Crypto Kings Promo" is listed under "Handled"

  Scenario: The queue shows where a report came from only within the administrator's ordinary access
    Given a private group "Quiet Circle" exists with owner "spam589@example.com"
    And "member589@example.com" is a member of "Quiet Circle"
    And "member589@example.com" has reported "spam589@example.com" for "other" from the group "Quiet Circle"
    And I am signed in as "admin589@example.com"
    When I visit "/admin/reports"
    Then "Crypto Kings Promo" is listed under "Open"
    And I should see "Other"
    And I should see "a group you cannot open"
    And I should not see "Quiet Circle"

  Scenario: A report expires after two years while the suspension stays
    Given "member589@example.com" reported "spam589@example.com" for "spam" two years ago
    And "admin589@example.com" suspends "spam589@example.com" for "Spam"
    And I am signed in as "admin589@example.com"
    When I visit "/admin/reports"
    Then I should see "Nothing to review"
    And "spam589@example.com" is suspended
    When I read the reports through the API
    Then no reports are returned

  @public_organizer_report
  Scenario: A confirmed visitor reports a public organizer without joining or RSVPing
    Given I am signed in as "outsider589@example.com"
    When I visit the huddl page for "Elixir Hack Night"
    Then I should see "RSVP to see who's going."
    When I choose "Report account" from the menu for "Owner Olive"
    And I choose "Spam or advertising"
    And I confirm with "Report account"
    Then I should see "Thanks—we've received your report."
    And there is exactly 1 report about "owner589@example.com"
    When I report "owner589@example.com" through the API
    Then the report is accepted
    When I report "owner589@example.com" for "spam" saying "" through JSON:API
    Then the JSON:API report is accepted

  @reopen_report
  Scenario: An administrator reopens an accidentally handled report
    Given "member589@example.com" has reported "spam589@example.com" for "spam"
    And I am signed in as "admin589@example.com"
    When I visit "/admin/reports"
    And I choose "Mark handled" from the menu for "Crypto Kings Promo"
    And I click "Handled"
    And I click "Review"
    And I click "Reopen" in the review card
    Then I should see "Report reopened"
    And "Crypto Kings Promo" is listed under "Open"
    And I should see "Also open on this account"

  @account_report_navigation
  Scenario: Account review links to only that account's reports
    Given "member589@example.com" has reported "spam589@example.com" for "spam" saying "Repeated coin advertisements"
    And "member589@example.com" has reported "owner589@example.com" for "other" saying "An unrelated concern"
    And "admin589@example.com" suspends "spam589@example.com" for "Spam"
    And I am signed in as "admin589@example.com"
    When I visit "/admin/users?scope=suspended"
    And I click "Review"
    And I click "1 open report"
    Then I should see "Repeated coin advertisements"
    And I should not see "An unrelated concern"
    When I click "Review"
    And I click "Mark handled" in the review card
    And I click "Handled"
    And I click "Review"
    And I click "Reopen" in the review card
    Then I should see "Report reopened"
    And I should not see "An unrelated concern"
    When I click "All reports"
    Then I should see "An unrelated concern"

  @suspended_report_controls
  Scenario: A suspended account cannot be suspended again from Reports
    Given "member589@example.com" has reported "spam589@example.com" for "spam"
    And "admin589@example.com" suspends "spam589@example.com" for "Spam"
    And I am signed in as "admin589@example.com"
    When I visit "/admin/reports"
    Then I should not see "Suspend account"
    When I click "Review"
    Then I should not see "Suspend account"
    And I should see "Mark handled"
