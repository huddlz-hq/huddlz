@email_confirmation_browser
Feature: Confirmation recovery from profile
  Scenario: Resending from profile after hiding the reminder
    Given I have hidden the reminder for my unconfirmed address in a browser
    When I request confirmation from my profile
    Then a confirmation email is sent to my current address
    And I can still save my display name
