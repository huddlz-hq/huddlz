@async @database @conn
Feature: Valid notification preference updates
  As a user updating my notification preferences through the API
  I want invalid changes to be rejected together
  So that my saved email choices are preserved

  Scenario Outline: Invalid preferences leave all saved choices unchanged
    Given I have opted out of RSVP confirmations through the API
    When I request these notification preferences through the API:
      | preference        | value   |
      | rsvp_confirmation | true    |
      | <preference>      | <value> |
    Then the notification preference update should be rejected
    And my saved notification preferences should be unchanged

    Examples:
      | preference    | value   |
      | unknown       | true    |
      | rsvp_received | "false" |
