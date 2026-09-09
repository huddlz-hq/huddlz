@database @conn
Feature: Link previews for huddlz without a cover picture
  When someone pastes a huddl link into a chat, the preview should carry a
  picture even if the organizer never uploaded a cover.

  Scenario: A public huddl without a cover advertises a generated preview picture
    Given a public group "Phoenix Elixir Meetup" hosting an upcoming huddl "Hands-on with Ash Framework" with no cover picture
    When a link preview fetches the huddl page
    Then the page advertises a generated preview picture
    And that picture is a 1200 by 630 PNG

  Scenario: A private huddl has no preview picture to fetch
    Given a private huddl "Board planning session" with no cover picture
    When a link preview fetches that huddl's preview picture
    Then there is nothing to fetch
