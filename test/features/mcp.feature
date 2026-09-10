@database @conn @mcp
Feature: Discover and join huddlz with an agent
  As a member using an MCP client
  I want my agent to discover huddlz and manage my participation
  So that I can make plans in a conversation

  Scenario: Agent discovery requires a connection to my account
    When an anonymous agent searches for huddlz
    Then the agent is directed to connect with OAuth

  Scenario: Connect an agent while signed out and discover my search location
    Given I connect an agent to my account using OAuth
    When my agent asks for my search context
    Then it receives my home search location without my email address

  Scenario: Find nearby yoga within a local evening
    Given I connect an agent to my account using OAuth
    And yoga huddlz are scheduled near home, far away, and outside the evening
    When my agent searches for yoga during that evening
    Then it receives only the nearby yoga huddl within that evening

  Scenario: Sign me up after I choose a huddl
    Given I connect an agent to my account using OAuth
    And yoga huddlz are scheduled near home, far away, and outside the evening
    When my agent tries to RSVP without my confirmation
    Then my attendance is unchanged
    When I tell my agent to sign me up for the nearby yoga huddl
    Then my agent can verify my confirmed RSVP

  Scenario: Cancel my RSVP through my agent
    Given I connect an agent to my account using OAuth
    And yoga huddlz are scheduled near home, far away, and outside the evening
    When I tell my agent to sign me up for the nearby yoga huddl
    And I tell my agent to cancel that RSVP
    Then my attendance is unchanged

  Scenario: Choose a waitlist when a huddl is full
    Given I connect an agent to my account using OAuth
    And yoga huddlz are scheduled near home, far away, and outside the evening
    And the nearby yoga huddl is full
    When I ask my agent to join its waitlist
    Then my agent reports waitlisted rather than confirmed
    When I tell my agent to cancel that RSVP
    Then my attendance is unchanged

  Scenario: Discover a group and manage only my own membership
    Given I connect an agent to my account using OAuth
    And yoga huddlz are scheduled near home, far away, and outside the evening
    When my agent discovers and reads the yoga group
    And I ask my agent to join the yoga group
    Then the yoga group appears in my groups
    When I ask my agent to leave the yoga group
    Then the yoga group no longer appears in my groups

  Scenario: An agent cannot silently send arguments outside the schema
    Given I connect an agent to my account using OAuth
    When my agent sends search arguments outside the input object
    Then it receives a useful tool error

  Scenario: Discovery is paginated and tools are narrowly described
    Given I connect an agent to my account using OAuth
    And yoga huddlz are scheduled near home, far away, and outside the evening
    Then my agent can page through huddlz without duplicates
    And its tool catalog contains only the agreed tools with described arguments

  Scenario: A client can rotate and revoke its credentials
    Given I connect an agent to my account using OAuth
    Then its authorization code cannot be reused
    And its refresh token rotates and can be revoked

  Scenario: Busy agents and registration attempts are rate limited
    Given I connect an agent to my account using OAuth
    When the MCP rate limits are enabled
    Then repeated agent calls receive a retry delay
    And repeated client registrations receive a retry delay

  Scenario: MCP rejects credentials from other authentication contexts
    Given I connect an agent to my account using OAuth
    Then website tokens, API keys, expired tokens, and missing scopes cannot call MCP

  Scenario: Invalid searches and inaccessible huddlz fail safely
    Given I connect an agent to my account using OAuth
    And yoga huddlz are scheduled near home, far away, and outside the evening
    Then invalid search arguments receive tool errors
    And another person's private huddl cannot be read or joined
    And a member without a home location must choose a search location

  Scenario: Find MCP setup from Help
    When I open Help for agent setup
    Then Help links to the MCP usage guide
