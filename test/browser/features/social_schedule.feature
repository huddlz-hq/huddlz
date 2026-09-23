@browser_smoke @social_schedule_browser
Feature: Editing a social schedule in the browser
  Scenario: Keyboard changes and the last opening-line edit are saved
    Given I am editing a social connection as its owner
    When I choose morning-of posting with Space
    Then the social schedule choice stays focused and checked
    When I enter an opening line and finish immediately
    Then reopening the social schedule shows both changes

  @mobile
  Scenario: A social schedule can be edited on a phone
    Given I am editing a social connection as its owner
    When I choose morning-of posting with Space
    And I enter an opening line and finish immediately
    Then reopening the social schedule shows both changes
