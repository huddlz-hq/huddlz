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

  Scenario: Browser history restores the schedule after returning from a provider
    Given I have returned to Social after connecting a place
    When I finish its schedule and open Members
    Then Back returns to Social and back again reopens the connected place's schedule
    And Forward returns to Social with the schedule closed

  @social_removal_browser
  Scenario: The owner can reconsider removing a place before disconnecting it
    Given I am editing a social connection as its owner
    When I ask to remove the place and cancel
    Then I can continue editing its schedule
    When I ask to remove the place again and confirm
    Then Social lists no connected places
