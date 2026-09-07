@photo_browser
Feature: Sharing photos in the browser
  Scenario: One oversized photo does not block the other photos
    Given I am viewing my completed huddl in the browser
    When I select a valid photo and an oversized photo
    Then I can upload the valid photo and understand why the other was skipped

  Scenario: A disguised non-image receives an actionable explanation
    Given I am viewing my completed huddl in the browser
    When I select a corrupt image and submit it
    Then I am told to choose a supported image instead of retrying it

  @mobile
  Scenario: Sharing and viewing memories with the keyboard on a narrow screen
    Given I am viewing my completed huddl in the browser
    When I choose two photos using the keyboard upload control
    Then the upload queue names each photo and its remove control
    When I share the selected photos and open the first one
    Then I can navigate with arrow keys and see the contributor and photo position
    And Escape returns focus to the photo I opened
    And the gallery fits above the huddl details on mobile
    When I consider deleting the first photo
    Then I see which photo will be deleted and can keep it
