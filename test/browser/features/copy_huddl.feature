@copy_huddl_browser @mobile
Feature: Copying a huddl on a phone
  Scenario: Scheduling controls remain available while reviewing copied details
    Given I opened a copied huddl on my phone
    When I review the copied description
    Then I can reach Schedule huddl and Save as draft without scrolling
