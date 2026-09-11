@browser_smoke @preferences_browser
Feature: Notification preferences in a browser
  Scenario: A save that fails puts the switch back
    Given I have opened my notification preferences in a browser
    And my account has been removed underneath the page
    When I flip "Confirmation when I RSVP to a huddl" off
    Then the row says the change could not be saved
    And "Confirmation when I RSVP to a huddl" is shown as on
