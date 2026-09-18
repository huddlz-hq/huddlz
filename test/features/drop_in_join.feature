@database @conn @drop_in
Feature: Drop-ins can join the group from the huddl page
  As someone going to a huddl of a group I have not joined
  I want to be told once that I can join the group
  So that I hear about its next huddlz without joining being forced on me

  Background:
    Given the following users exist:
      | email                | display_name |
      | owner604@example.com | Owner Olive  |
      | maya604@example.com  | Maya Chen    |
    And a public group "Portland Elixir" exists with owner "owner604@example.com"
    And an upcoming huddl "Elixir hack night" exists in "Portland Elixir"

  Scenario: A signed-in non-member can join the group from the huddl page
    Given I am signed in as "maya604@example.com"
    When I visit the huddl "Elixir hack night"
    Then I can join "Portland Elixir" from the huddl page
    When I join "Portland Elixir" from the huddl page
    Then I am shown as a member of "Portland Elixir" on the huddl page
    And "maya604@example.com" belongs to "Portland Elixir"
