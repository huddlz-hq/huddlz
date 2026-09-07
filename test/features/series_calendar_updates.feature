@database @conn @series_calendar_updates
Feature: Calendar entries after a recurring series update
  As an attendee of recurring huddlz
  I want refreshed calendar entries for the dates I have RSVPed to
  So that my calendar reflects the organizer's schedule changes

  Scenario: A weekly series moves one hour across daylight saving time
    Given attendees hold different dates of a weekly series across daylight saving time
    When the organizer moves the whole series one hour later
    Then each attendee receives one series email with calendar entries for only their RSVPs
    And each calendar entry keeps its original identity and the new local schedule

  Scenario: Series calendar delivery respects participation and preferences
    Given attendees hold different dates of a weekly series across daylight saving time
    And other people have waitlisted, cancelled, or disabled series emails
    When the organizer moves the whole series one hour later
    Then each attendee receives one series email with calendar entries for only their RSVPs
    And waitlisted people receive only a summary and opted-out people receive no email

  Scenario: Shortening a series does not re-add cancelled dates to calendars
    Given attendees hold different dates of a weekly series across daylight saving time
    When the organizer shortens the series to its first two dates
    Then series attachments contain only retained dates and dropped dates have cancellation emails

  Scenario: An attendee cannot trigger series calendar updates
    Given attendees hold different dates of a weekly series across daylight saving time
    When an attendee tries to edit the whole series
    Then the edit is forbidden and no update email is sent
