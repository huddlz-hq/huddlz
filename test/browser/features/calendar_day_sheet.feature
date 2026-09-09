@browser_smoke @mobile @calendar_day_browser
Feature: Day sheet on a phone
  On a narrow screen the month grid has no room for titles, so a day opens
  as a bottom sheet. The open day lives in the address, so the browser's
  back button returns to the sheet, and to where the page was scrolled.

  Scenario: A day opens as a bottom sheet and the back button returns to it
    Given I am going to "Elixir office hours" on the 17th of next month
    And I have opened next month's calendar in a narrow browser
    When I tap the 17th
    Then the day sheet is docked to the bottom edge and lists "Elixir office hours"
    When I open "Elixir office hours" from the sheet and go back
    Then the calendar returns with the sheet open on the 17th where I left it
