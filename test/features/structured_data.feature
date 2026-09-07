@database @conn @structured_data
Feature: Public structured data
  Scenario: An anonymous crawler reads a public huddl's schedule and organizer
    Given a public in-person huddl with a known schedule and address
    When a crawler requests the huddl page without signing in
    Then the initial HTML describes that huddl once as structured data

  Scenario: An anonymous crawler identifies a public group
    Given a public in-person huddl with a known schedule and address
    When a crawler requests the group page without signing in
    Then the initial HTML describes the public group once as an organization
