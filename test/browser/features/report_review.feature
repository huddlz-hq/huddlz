@report_review_browser
Feature: Staff review controls remain usable across screen sizes
  Scenario: Review reports and accounts on desktop
    Given I am reviewing a reported account in a browser
    Then the report review controls stay together
    When I handle and reopen the report
    Then the reopened report is ready for review
    When I review the suspended account in Users
    Then the account review controls stay together

  @mobile
  Scenario: Review reports and accounts on a phone
    Given I am reviewing a reported account in a browser
    Then the report review controls stay together
    When I handle and reopen the report
    Then the reopened report is ready for review
    When I review the suspended account in Users
    Then the account review controls stay together
