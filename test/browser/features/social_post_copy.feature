@clipboard_browser @social_post_clipboard_browser
Feature: Copy a huddl's social post
  Scenario Outline: Copying the complete post with direct clipboard access <availability>
    Given I am viewing a public huddl in the organize workspace to copy its post
    And direct clipboard access is "<availability>"
    When I copy the post from the Social posts panel
    Then my clipboard holds the huddl's title, time, place and link on separate lines
    And the Social posts panel confirms the post was copied
    And the copy button returns to Copy post

    Examples:
      | availability |
      | available    |
      | unavailable  |
      | rejected     |
