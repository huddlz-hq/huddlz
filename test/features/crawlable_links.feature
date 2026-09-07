@database @conn @crawlable_links
Feature: Discover public huddlz through ordinary links
  Scenario: An anonymous visitor follows discovery pagination without JavaScript
    Given more than one page of public huddlz for crawling
    When a crawler follows Browse huddlz from the home page
    Then the crawler can follow discovery pages to every public huddl
