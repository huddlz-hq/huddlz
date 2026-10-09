@async @database @conn @landing_nudge
Feature: Adaptive landing nudge
  As a signed-in person whose landing page keeps sending them elsewhere
  I want huddlz to notice and offer to change where I land
  So that I stop paying the same click every time I sign in

  Scenario: Repeatedly leaving the landing page earns an offer to change it
    Given I am signed in as "nudge-offer@example.com" with password "Password123!"
    When I visit "/agenda"
    Then I should not see "Change where you land after login?"
    When I leave my landing page for "/discover" 3 times
    And I visit "/agenda"
    Then I should see "Change where you land after login?"

  Scenario: Choosing a new landing is honored by the next sign-in
    Given I am signed in as "nudge-change@example.com" with password "Password123!"
    And I have left my landing page often enough to be offered a change
    When I visit "/agenda"
    And I click the "Land on Discover" button
    Then I should see "You'll land on Discover after signing in" in the flash
    And I should not see "Change where you land after login?"
    When I sign in again with password "Password123!"
    Then I should land on "/discover"

  Scenario: Dismissing the offer leaves it available on a later visit
    Given I am signed in as "nudge-dismiss@example.com" with password "Password123!"
    And I have left my landing page often enough to be offered a change
    When I visit "/agenda"
    And I click the "Not now" button
    Then I should not see "Change where you land after login?"
    When I visit "/agenda"
    Then I should see "Change where you land after login?"

  Scenario: Asking not to be asked again stops the offer for good
    Given I am signed in as "nudge-never@example.com" with password "Password123!"
    And I have left my landing page often enough to be offered a change
    When I visit "/agenda"
    And I click the "Don't ask again" button
    Then I should not see "Change where you land after login?"
    When I leave my landing page for "/discover" 3 times
    And I visit "/agenda"
    Then I should not see "Change where you land after login?"
