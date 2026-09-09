@database @conn
Feature: Link previews without a cover picture
  When someone pastes a huddl or group link into a chat, the preview should
  carry a picture even if the organizer never uploaded a cover. For a huddl the
  picture cascades: its own cover, then its group's cover, then a card drawn on
  the fly. For a group: its cover, then a card.

  Scenario: A public huddl without a cover advertises a generated preview picture
    Given a public group "Phoenix Elixir Meetup" hosting an upcoming huddl "Hands-on with Ash Framework" with no cover picture
    When a link preview fetches the huddl page
    Then the page advertises a generated preview picture
    And that picture is a 1200 by 630 PNG

  Scenario: A huddl without its own cover shares its group's cover picture
    Given a public group "Phoenix Elixir Meetup" with a cover picture
    And an upcoming huddl "Hands-on with Ash Framework" in that group with no cover of its own
    When a link preview fetches the huddl page
    Then the page advertises the group's cover picture

  Scenario: A private huddl has no preview picture to fetch
    Given a private huddl "Board planning session" with no cover picture
    When a link preview fetches that huddl's preview picture
    Then there is nothing to fetch

  Scenario: A public group without a cover advertises a generated preview picture
    Given a public group "Phoenix Elixir Meetup" with no cover picture
    When a link preview fetches the group page
    Then the page advertises a generated group preview picture
    And that picture is a 1200 by 630 PNG

  Scenario: A private group has no preview picture to fetch
    Given a private group "Board of directors"
    When a link preview fetches that group's preview picture
    Then there is nothing to fetch
