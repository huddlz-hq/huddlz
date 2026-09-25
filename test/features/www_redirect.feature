@async @database @www_redirect
Feature: Use the primary huddlz address
  Scenario: A visitor opens a saved www link
    When a visitor requests "https://www.huddlz.com/discover?search=board%20games&scope=all"
    Then they are permanently redirected to "https://huddlz.com/discover?search=board%20games&scope=all"
