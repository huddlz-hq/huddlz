@database @conn @crawlable_links
Feature: Discover public huddlz through ordinary links
  Scenario: An anonymous visitor follows discovery pagination without JavaScript
    Given more than one page of public huddlz for crawling
    When a crawler follows Browse huddlz from the home page
    Then the crawler can follow discovery pages to every public huddl

  Scenario: An anonymous visitor discovers a group's public archive without JavaScript
    Given a public group with more than one page of past huddlz
    When a crawler follows group discovery to the group's Past link
    Then the crawler can follow archive pages to every past public huddl
