@browser_smoke
Feature: Home location keyboard selection in a browser
  As a member
  I want to choose my home location with the keyboard
  So I can set my search location without a mouse

  Scenario: Enter selects a suggestion without submitting the profile form
    Given I have opened my profile in a browser
    When I type "saint" into my home location
    And I highlight the first home location suggestion
    And I select the highlighted home location with Enter
    Then my home location is "Saint Augustine, FL, USA"
    And Enter did not submit a form
