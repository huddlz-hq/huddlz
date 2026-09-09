@browser_smoke @picture_browser
Feature: Profile picture browser interaction
  Scenario: Removing a profile picture through the confirmation dialog
    Given I have opened my profile in a browser
    When I upload a profile picture through the file input
    And I open the remove picture confirmation by clicking Remove
    Then the Remove picture button is above the backdrop
    When I confirm picture removal by clicking Remove picture
    Then my profile picture is replaced by initials

  Scenario: A real upload renders and its confirmation dialog contains keyboard focus
    Given I have opened my profile in a browser
    When I upload a profile picture through the file input
    Then my uploaded picture is decoded and displayed by the browser
    When I open the remove picture confirmation with the keyboard
    Then Tab stays inside the confirmation dialog
    When I dismiss the confirmation with Escape
    Then focus returns to Remove and my picture remains
