@database @conn @sitemap
Feature: Discover public pages through sitemaps
  Scenario: A crawler discovers public canonical pages
    Given a public group with a published huddl for sitemap discovery
    When the scheduled sitemap refresh finishes
    Then the anonymous sitemap index links to XML containing the public canonical pages

  Scenario: Publishing and removing a group preserves unrelated sitemap children
    Given a public group with a published huddl for sitemap discovery
    And a crawler has cached the sitemap child containing that huddl
    When another public group is published and the sitemap refreshes
    Then the current sitemap still links to the cached huddl child
    When that other group is deleted and the sitemap refreshes
    Then the current sitemap still links to the cached huddl child
