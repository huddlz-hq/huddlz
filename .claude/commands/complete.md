<prompt>
  <params>
    # No required parameters - works with current branch context
  </params>

  <instructions>
    # Complete Work and Create Pull Request

    This command finalizes work on the current feature branch and creates a pull request.

    ## Pre-Completion Checks

    1. Verify branch status:
       ```
       git status
       git diff --stat
       ```
       - Ensure all changes are committed
       - Check branch name for issue number

    2. Extract issue number from branch name:
       - Pattern: `issue-([0-9]+)-.*`
       - If no issue number found, ask user to provide it

    ## Quality Assurance

    3. Run comprehensive checks:
       ```
       mix format
       mix test
       mix credo --strict
       ```
       - Fix any formatting issues automatically
       - Document test results
       - Note any credo warnings

    4. Commit any formatting fixes:
       ```
       git add -A
       git commit -m "style: apply formatting and linting fixes"
       ```

    ## Session Note Finalization

    5. Find and update session note:
       - Look for `notes/session-*-issue-[number].md`
       - Add completion summary:
         ```
         ## Completion Summary
         - Total commits: [count]
         - Files changed: [count]
         - Tests added/modified: [list]
         - All tests passing: [yes/no]

         ## Key Changes
         [Brief summary of implementation]
         ```

    ## Pull Request Creation

    6. Push latest changes:
       ```
       git push
       ```

    7. Create PR using gh CLI:
       ```
       gh pr create \
         --title "[Type]: [Description] (closes #[issue])" \
         --body "[PR body content]" \
         --assignee @me
       ```

    8. PR body template:
       ```markdown
       ## Summary
       [Brief description of changes]

       Closes #[issue-number]

       ## Changes Made
       - [Key change 1]
       - [Key change 2]
       - [etc.]

       ## Testing
       - [x] All existing tests pass
       - [x] Added tests for new functionality
       - [x] Manual testing completed

       ## Checklist
       - [x] Code follows project style guidelines
       - [x] Tests have been added/updated
       - [x] Documentation has been updated
       - [x] Changes have been formatted with `mix format`
       - [x] Credo checks pass

       ## Session Notes
       See: [link to session note file]

       ## Screenshots (if applicable)
       [Add any relevant screenshots]
       ```

    ## Knowledge Capture

    9. If significant learnings exist:
       - Prompt user: "Any key learnings to add to LEARNINGS.md?"
       - If yes, update LEARNINGS.md with insights

    ## Cleanup Options

    10. Ask user:
        - "Switch back to main branch?"
        - "Delete local feature branch after PR merge?"

    ## Return Values

    Return:
    - PR URL created
    - Issue number closed
    - Summary of changes
    - Any remaining tasks
  </instructions>
</prompt>