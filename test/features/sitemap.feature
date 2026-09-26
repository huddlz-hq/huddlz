@async @database @conn @sitemap
Feature: Discover public pages through sitemaps
  Scenario: A crawler discovers public canonical pages
    Given a public group with a published huddl for sitemap discovery
    When the scheduled sitemap refresh finishes
    Then the anonymous sitemap index links to XML containing the public canonical pages

  @sitemap_horizon
  Scenario: A crawler discovers nearer recurring dates without losing access to later dates
    Given a public group with recurring huddlz next week and next year
    When the scheduled sitemap refresh finishes
    Then the sitemap lists the group and next week's recurring huddl but not next year's
    And next year's recurring huddl remains publicly accessible at its canonical URL

  Scenario: Publishing and removing a group preserves unrelated sitemap children
    Given a public group with a published huddl for sitemap discovery
    And a crawler has cached the sitemap child containing that huddl
    When another public group is published and the sitemap refreshes
    Then the current sitemap still links to the cached huddl child
    When that other group is deleted and the sitemap refreshes
    Then the current sitemap still links to the cached huddl child
