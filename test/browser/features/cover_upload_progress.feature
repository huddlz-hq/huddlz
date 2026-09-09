@browser_smoke @upload_browser
Feature: Cover upload in progress
  The cover slot on the group form must hold its place while a picture
  is chosen, uploaded and prepared, and the rest of the form must stay
  usable the whole time. That depends on the upload JavaScript, so it is
  checked in a real browser.

  Scenario: Choosing a picture fills the slot at once and nothing else moves
    Given I am creating a group in a browser where preparing a cover takes a moment
    When I choose a picture for the cover
    Then the slot shows my picture with the upload in progress and the form is still usable
    And the slot settles on the prepared cover without moving
