@browser_smoke @mobile @rsvp_browser
Feature: RSVP within reach on a phone
  On a narrow screen the RSVP panel sits below the cover, title and
  description, so the primary action would otherwise be off screen. It is
  docked to the bottom edge instead, and stays there as the page scrolls.

  Scenario: The RSVP action is docked to the bottom of a narrow screen
    Given I am viewing an upcoming huddl in a narrow browser
    Then the RSVP button is docked to the bottom edge before I scroll
    When I scroll to the end of the page
    Then the dock still sits on the bottom edge and covers nothing
    When I RSVP from the dock
    Then the dock shows I am attending and offers to cancel
