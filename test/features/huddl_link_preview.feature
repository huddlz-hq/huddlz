@database @conn @huddl_link_preview
Feature: Shared huddl links say when the huddl is
  Pasting a huddl link into a chat should tell readers when it takes place
  without opening it. The preview's title carries the date and start time in
  the huddl's own zone, next to its name; the description and picture stay
  as they were.

  Scenario: A shared huddl link says when it takes place
    Given a public huddl "Community lunch" in "America/New_York" on 2030-07-20 at 12:00
    When a link preview fetches the huddl page
    Then the preview title reads "Community lunch · Sat, Jul 20, 2030 · 12:00 PM EDT"
    And the huddl page shows "Sat, Jul 20"
    And the huddl page shows "12:00 PM"
    And the preview still carries the huddl's description and picture

  Scenario: The time is the huddl's own, not the reader's
    Given a public huddl "Community lunch" in "America/Chicago" on 2030-07-20 at 12:00
    When a link preview fetches the huddl page
    Then the preview title reads "Community lunch · Sat, Jul 20, 2030 · 12:00 PM CDT"
