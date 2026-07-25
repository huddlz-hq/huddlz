defmodule Huddlz.LegalTest do
  use ExUnit.Case, async: true

  alias Huddlz.Legal.Markdown

  test "keeps wrapped list text in the same list item" do
    markdown = """
    # Test Policy

    **Version:** 2026-07-25

    - a list item that wraps onto
      another source line;
    - a second item.

    1. an ordered item that also
       wraps across source lines;
    2. another ordered item.
    """

    assert %{
             blocks: [
               {:unordered_list,
                [
                  "a list item that wraps onto another source line;",
                  "a second item."
                ]},
               {:ordered_list,
                [
                  "an ordered item that also wraps across source lines;",
                  "another ordered item."
                ]}
             ]
           } = Markdown.parse(markdown)
  end
end
