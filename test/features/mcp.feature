# Keep serial: scenarios change global rate-limit configuration.
@database @conn @mcp
Feature: Discover and join huddlz with an agent
  As a member using an MCP client
  I want my agent to discover huddlz and manage my participation
  So that I can make plans in a conversation

  Scenario: Agent discovery requires a connection to my account
    When an anonymous agent searches for huddlz
    Then the agent is told to use an API key

  Scenario: Discover my search location
    Given I connect an agent to my account with an API key
    When my agent asks for my search context
    Then it receives my home search location without my email address

  Scenario: Find nearby yoga within a local evening
    Given I connect an agent to my account with an API key
    And yoga huddlz are scheduled near home, far away, and outside the evening
    When my agent searches for yoga during that evening
    Then it receives only the nearby yoga huddl within that evening

  Scenario: Sign me up after I choose a huddl
    Given I connect an agent to my account with an API key
    And yoga huddlz are scheduled near home, far away, and outside the evening
    When my agent tries to RSVP without my confirmation
    Then my attendance is unchanged
    When I tell my agent to sign me up for the nearby yoga huddl
    Then my agent can verify my confirmed RSVP

  Scenario: Cancel my RSVP through my agent
    Given I connect an agent to my account with an API key
    And yoga huddlz are scheduled near home, far away, and outside the evening
    When I tell my agent to sign me up for the nearby yoga huddl
    And I tell my agent to cancel that RSVP
    Then my attendance is unchanged

  Scenario: Choose a waitlist when a huddl is full
    Given I connect an agent to my account with an API key
    And yoga huddlz are scheduled near home, far away, and outside the evening
    And the nearby yoga huddl is full
    When I ask my agent to join its waitlist
    Then my agent reports waitlisted rather than confirmed
    When I tell my agent to cancel that RSVP
    Then my attendance is unchanged

  Scenario: Discover a group and manage only my own membership
    Given I connect an agent to my account with an API key
    And yoga huddlz are scheduled near home, far away, and outside the evening
    When my agent discovers and reads the yoga group
    And I ask my agent to join the yoga group
    Then the yoga group appears in my groups
    When I ask my agent to leave the yoga group
    Then the yoga group no longer appears in my groups

  Scenario: An agent cannot silently send arguments outside the schema
    Given I connect an agent to my account with an API key
    When my agent sends search arguments outside the input object
    Then it receives a useful tool error

  Scenario: Discovery is paginated and tools are narrowly described
    Given I connect an agent to my account with an API key
    And yoga huddlz are scheduled near home, far away, and outside the evening
    Then my agent can page through huddlz without duplicates
    And its tool catalog contains only the agreed tools with described arguments

  Scenario: Busy agents are rate limited
    Given I connect an agent to my account with an API key
    When the MCP rate limits are enabled
    Then repeated agent calls receive a retry delay

  Scenario: A revoked or expired key is refused
    Given I connect an agent to my account with an API key
    When I revoke my agent's key
    Then my agent is refused
    Given I connect an agent to my account with a key that has expired
    Then my agent is refused

  Scenario: A suspended person's key is refused
    Given I connect an agent to my account with an API key
    When an administrator suspends my account
    Then my agent is refused

  Scenario: Invalid searches and inaccessible huddlz fail safely
    Given I connect an agent to my account with an API key
    And yoga huddlz are scheduled near home, far away, and outside the evening
    Then invalid search arguments receive tool errors
    And another person's private huddl cannot be read or joined
    And a member without a home location must choose a search location

  Scenario: Find the agent setup guide from Help
    Given I am signed in as a member with a confirmed address
    When I visit "/help"
    And I click "Connect an agent"
    Then I should see "Add huddlz to your agent"
    And the guide explains how to add huddlz to Claude Code and Codex CLI
    When I click "Create a key"
    Then I should see "Your keys"
