@database @conn @sitemap
Feature: Discover public pages through sitemaps
  Scenario: A crawler discovers public canonical pages
    Given a public group with a published huddl for sitemap discovery
    When the scheduled sitemap refresh finishes
    Then the anonymous sitemap index links to XML containing the public canonical pages
