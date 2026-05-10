@async @database @conn
Feature: Global Footer
  As a visitor to the site
  I want a footer that groups product, help, legal, and open-source links
  So that I can find supporting pages without hunting for them

  Scenario: Footer surfaces grouped columns and the tagline
    When I visit "/discover"
    Then the footer should show the huddlz brand block
    And the footer should expose the Product, Help, Legal, and Open columns
    And the footer should link to GitHub and the API docs
    And the footer should show the closing line "Built for real-life gatherings"
