@async @database @conn @search_indexing
Feature: Keep account access pages out of search results
  Scenario: Crawlers exclude account access pages regardless of the return destination
    Given a public group with a published huddl for sitemap discovery
    When a crawler visits account access pages with and without a return destination
    Then each account access response asks search engines not to index it
    And public discovery, group and huddl pages still allow indexing
