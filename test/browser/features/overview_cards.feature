@browser_smoke @cards_browser
Feature: Overview summary cards in a browser
  Scenario: The Show rate card matches its neighbours before and after turnout
    Given I have opened the overview of a group with an uncounted past huddl
    Then the Show rate card is as tall as the RSVPs card
    When I record turnout from the overview reminder
    Then the Show rate card shows a rate and is still as tall as the RSVPs card
