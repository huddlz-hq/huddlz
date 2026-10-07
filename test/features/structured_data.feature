# Keep serial: a sitemap refresh holds a database-wide advisory lock until the
# sandbox transaction ends, so a concurrent refresh would skip generation.
@database @conn @structured_data
Feature: Public structured data
  Scenario: An anonymous crawler reads a public huddl's schedule and organizer
    Given a public in-person huddl with a known schedule and address
    When a crawler requests the huddl page without signing in
    Then the initial HTML describes that huddl once as structured data

  @location_name
  Scenario: A crawler and visitor can identify a named huddl location
    Given a public in-person huddl with a known schedule and address
    And its address book location is named "Community Center"
    When a crawler requests the huddl page without signing in
    Then the public huddl names "Community Center" as its location

  @location_name
  Scenario: Unknown admission and location details are not invented
    Given a public in-person huddl with a known schedule and address
    And an unnamed address book location is chosen for that huddl
    When a crawler requests the huddl page without signing in
    Then the public huddl provides its address without inventing a location name
    And the public huddl makes no admission price or performer claim

  Scenario: An anonymous crawler identifies a public group
    Given a public in-person huddl with a known schedule and address
    When a crawler requests the group page without signing in
    Then the initial HTML describes the public group once as an organization

  Scenario: A public cancellation preserves its schedule without disclosing its reason
    Given a public in-person huddl with a known schedule and address
    And the organizer cancels that huddl with a private reason
    When a crawler requests the huddl page without signing in
    Then the public page reports cancellation with the original schedule
    And the cancelled huddl is in the sitemap but absent from discovery

  Scenario: Rescheduling shows the immediately previous start alongside current dates
    Given a public in-person huddl with a known schedule and address
    And the organizer moves that huddl to July 21 then July 22
    When a crawler requests the huddl page without signing in
    Then the public page shows July 22 with July 21 as the previous start

  Scenario Outline: Private lifecycle details stay out of public pages and metadata
    Given a public in-person huddl with a known schedule and address
    And that huddl has <privacy> privacy and is <change>
    Then a crawler cannot read the huddl or find it in the sitemap

    Examples:
      | privacy | change      |
      | huddl   | cancelled   |
      | group   | cancelled   |
      | huddl   | rescheduled |
      | group   | rescheduled |

  Scenario: Cancellation takes precedence over an earlier reschedule
    Given a public in-person huddl with a known schedule and address
    And the organizer moves that huddl to July 21 then July 22
    And the organizer cancels that huddl with a private reason
    When a crawler requests the huddl page without signing in
    Then cancellation metadata preserves the July 22 schedule

  Scenario Outline: Changes that do not reschedule a published start invent no history
    Given a public in-person huddl with a known schedule and address
    And the organizer makes a <edit> schedule edit
    When a crawler requests the huddl page without signing in
    Then the public page shows a scheduled huddl without previous dates

    Examples:
      | edit     |
      | duration |
      | draft    |

  Scenario: Cancellation reasons remain restricted after the page becomes public
    Given a public in-person huddl with a known schedule and address
    And the organizer cancels that huddl with a private reason
    Then only an authorized viewer sees the cancellation reason

  Scenario: An expired cancellation keeps its page but leaves the sitemap
    Given a public in-person huddl with a known schedule and address
    And the cancelled huddl's scheduled end has passed
    When a crawler requests the huddl page without signing in
    Then the cancelled page retains its canonical URL but leaves the sitemap
