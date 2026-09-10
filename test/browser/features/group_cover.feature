@browser_smoke @cover_browser
Feature: Group cover rendering
  @mobile
  Scenario Outline: Narrow group pages remain readable across cover states
    Given a group with long details and a "<state>" cover
    When I open that group in the browser
    Then its cover has the expected image or visible fallback
    And its title and location fit without clipping or horizontal overflow
    And the mobile cover stays above the group details

    Examples:
      | state   |
      | valid   |
      | missing |
      | failed  |

  Scenario: A desktop cover renders above readable group details
    Given a group with long details and a "valid" cover
    When I open that group in the browser
    Then its cover has the expected image or visible fallback
    And its title and location fit without clipping or horizontal overflow
    And the group sidebar aligns with the top of the cover
