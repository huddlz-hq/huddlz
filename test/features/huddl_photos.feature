@async @database @conn @huddl_photos
Feature: Shared memories after a huddl
  Scenario: A creator awaiting email confirmation can browse shared photos
    Given a completed huddl with two shared photos
    When the creator opens the gallery with an unconfirmed address
    Then the creator can view the shared photos
    But the gallery offers no way to upload or delete photos

  Scenario: A removed photo disappears from another open gallery
    Given a completed huddl with two shared photos
    When I open its gallery in two tabs and remove a photo in one
    Then the other gallery no longer offers the removed photo

  Scenario: A storage failure leaves the gallery usable
    Given a completed huddl with two shared photos
    And one photo cannot currently be removed from storage
    When I try to remove that photo
    Then I see that deletion failed and can still view the gallery
