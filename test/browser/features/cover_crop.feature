@browser_smoke @crop_browser
Feature: Crop on upload
  A picture is cropped in the browser before it is uploaded, so the cover
  is exactly the part of the picture the organizer chose. That depends
  on the crop JavaScript and real pointer input, so it is checked in a
  real browser.

  Scenario: Cropping a tall picture before upload makes a 16:9 cover of the chosen part
    Given I am creating a group in a browser
    When I choose a tall picture for the cover
    Then the crop sheet opens with the picture fit to the 16:9 window
    When I drag the picture up to keep its bottom and use the photo
    Then the slot uploads a 16:9 cover showing only the bottom of my picture

  @mobile
  Scenario: Cropping with touch at 320px
    Given I am creating a group in a browser
    When I choose a tall picture for the cover
    Then the crop sheet fills the screen with the window and Use photo in view
    When I drag the picture up to keep its bottom and use the photo
    Then the slot uploads a 16:9 cover showing only the bottom of my picture
