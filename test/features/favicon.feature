@conn @favicon
Feature: The favicon is the brand mark
  The icon in the browser tab should be the same mark as the sidebar and the
  cards: a flat cyan rounded square with a dark "h", no glow.

  Scenario: The page links the icon set
    When a browser fetches the home page
    Then the page links an SVG favicon, an apple touch icon and a fallback ICO

  Scenario: The icons are the brand mark
    When a browser fetches the SVG favicon
    Then it is a cyan rounded square with a dark "h" and no glow effects

  Scenario: Every size is served
    When a browser fetches the home page
    And a browser fetches each linked icon
    Then each is served as an image of the size it is linked as

  Scenario: The icons are served under their cache-busting names
    When a browser fetches an icon by its cache-busting name
    Then the icon is served
