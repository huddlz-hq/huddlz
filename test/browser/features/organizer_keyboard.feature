@browser_smoke @organizer_browser
Feature: Organizer controls with a keyboard
  Scenario: Format and visibility choices work without a mouse
    Given I have opened a new huddl as its group organizer
    When I tab into the format choices and choose virtual with an arrow key
    Then the virtual choice has visible keyboard focus and reveals the online link
    When I enable recurrence and members only using Space
    Then both switches stay focused when changed and expose their checked state
