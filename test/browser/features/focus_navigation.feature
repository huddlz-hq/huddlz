@focus_browser
Feature: Keyboard access to page content
  Scenario: Skip persistent navigation and follow a page change
    Given I am signed in on the groups page for keyboard navigation
    When I use the skip link
    Then keyboard focus is in the main content
    When I follow the profile link
    Then the new page context receives keyboard focus

  Scenario: A failed sign in offers keyboard links to invalid fields
    Given I open sign in for keyboard navigation
    When I submit the empty sign in form
    Then the error summary receives focus and links to the invalid email
    When I follow the email error link
    Then the email field receives focus and describes its error

  Scenario: Correcting profile errors preserves typing focus and saving focuses the section
    Given I am signed in on the groups page for keyboard navigation
    When I follow the profile link
    And I submit an empty display name
    Then the profile error summary receives focus
    When I correct my display name
    Then typing focus stays in the display name field
    When I save my corrected profile
    Then the account information heading receives focus
    When I save my corrected profile
    Then the account information heading receives focus

  Scenario Outline: Organizer forms focus their invalid fields consistently
    Given I open the "<surface>" form as a group owner
    When I submit that form with an empty "<field>"
    Then that form shows a focused error summary with an invalid field link

    Examples:
      | surface       | field         |
      | group         | Group Name    |
      | huddl         | Title         |
      | address book  | Location name |
      | invitation    | Email         |

  Scenario: Dismissing the address dialog returns to its trigger
    Given I open the "address book" form as a group owner
    When I open the address dialog and dismiss it with Escape
    Then focus returns to Add Address

  Scenario: Dismissing group archival returns to Archive group
    Given I open the "group" form as a group owner
    When I open group archival and dismiss it with Escape
    Then focus returns to Archive group

  Scenario: Dismissing a member action returns to the member
    Given I open member management with a member to promote
    When I open promotion and dismiss it with Escape
    Then focus returns to Promote

  Scenario: A completed member action returns focus when its trigger disappears
    Given I open member management with a member to promote
    When I confirm the member promotion
    Then focus returns to the member page content

  Scenario: Saving an address-book name returns to page content
    Given I open the "address book" form as a group owner
    When I save a new address-book name
    Then keyboard focus is in the main content
