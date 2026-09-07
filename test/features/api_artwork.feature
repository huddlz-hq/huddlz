@async @database @conn @api_artwork
Feature: Artwork for API clients
  As a visitor using the public API
  I want the same artwork in discovery and huddl details
  So that I can recognize huddlz without signing in

  Scenario: Available artwork and missing artwork are usable
    Given public upcoming huddlz with their own artwork, group artwork, and no artwork
    When I discover those huddlz and open their details through the API without signing in
    Then both API responses provide the available artwork or no artwork
    And the available artwork can be downloaded
