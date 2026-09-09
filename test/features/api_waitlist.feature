@async @database @conn @api_waitlist
Feature: Join a huddl waitlist through the API
  As an authenticated API client
  I want to join a full huddl's waitlist and read my attendance state
  So that I can distinguish waiting from confirmed attendance

  Scenario Outline: Join a full huddl's waitlist
    Given a full public huddl and an authenticated API caller
    When I join the huddl waitlist through "<api>"
    Then the API reports my attendance as "waitlisted"
    And my API attendance history contains one waitlist entry
    And the API does not list me as a confirmed attendee

    Examples:
      | api      |
      | JSON:API |
      | GraphQL  |

  Scenario Outline: Repeat a waitlist request
    Given a full public huddl and an authenticated API caller
    And I authenticate the waitlist caller with an API key
    When I join the huddl waitlist through "<api>"
    And I join the huddl waitlist through "<api>"
    Then the API reports my attendance as "waitlisted"
    And my API attendance history contains one waitlist entry
    And the API does not list me as a confirmed attendee

    Examples:
      | api      |
      | JSON:API |
      | GraphQL  |

  Scenario Outline: RSVP success does not imply confirmed attendance
    Given a full public huddl and an authenticated API caller
    When I join the huddl waitlist through "<api>"
    And I RSVP to the huddl through "<api>"
    Then the API reports my attendance as "waitlisted"
    And my API attendance history contains one waitlist entry

    Examples:
      | api      |
      | JSON:API |
      | GraphQL  |

  Scenario Outline: An API key client confirms and cancels attendance
    Given a full public huddl and an authenticated API caller
    And I authenticate the waitlist caller with an API key
    And the last confirmed attendee cancels
    When I RSVP to the huddl through "<api>"
    Then the API reports my attendance as "confirmed"
    When I cancel my attendance through "<api>"
    Then the API reports my attendance as "none"

    Examples:
      | api      |
      | JSON:API |
      | GraphQL  |

  Scenario Outline: Unavailable or unauthorized waitlist requests fail
    Given a full public huddl and an authenticated API caller
    But the waitlist request is unavailable because "<reason>"
    When I join the huddl waitlist through "<api>"
    Then the API rejects the waitlist request
    And my API attendance history is empty

    Examples:
      | api      | reason          |
      | JSON:API | anonymous       |
      | GraphQL  | anonymous       |
      | JSON:API | private huddl   |
      | GraphQL  | private huddl   |
      | JSON:API | cancelled huddl |
      | GraphQL  | cancelled huddl |
      | JSON:API | open seats      |
      | GraphQL  | open seats      |
      | JSON:API | unlimited seats |
      | GraphQL  | unlimited seats |
      | JSON:API | missing huddl   |
      | GraphQL  | missing huddl   |
      | JSON:API | draft huddl     |
      | GraphQL  | draft huddl     |
      | JSON:API | completed huddl |
      | GraphQL  | completed huddl |

  Scenario Outline: Attendance state belongs to the current caller
    Given a full public huddl and an authenticated API caller
    When I join the huddl waitlist through "<api>"
    And I read the huddl attendance through "<api>" as "myself"
    Then the API reports my attendance as "waitlisted"
    When I read the huddl attendance through "<api>" as "another caller"
    Then the API reports my attendance as "none"
    When I read the huddl attendance through "<api>" as "anonymous"
    Then the API reports my attendance as "none"

    Examples:
      | api      |
      | JSON:API |
      | GraphQL  |

  Scenario Outline: A confirmed caller stays confirmed when requesting the waitlist
    Given a full public huddl and an authenticated API caller
    And I am the confirmed attendee
    When I join the huddl waitlist through "<api>"
    Then the API reports my attendance as "confirmed"

    Examples:
      | api      |
      | JSON:API |
      | GraphQL  |
