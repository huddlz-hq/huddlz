<prompt>
  <params>
    task_dir # Path or identifier for the task directory (full path, feature name, or timestamp)
    commit # Whether to commit changes after verification (true/false, default false)
  </params>

  <instructions>
    # Verification Phase
    
    This command performs comprehensive review and testing of a completed feature implementation.
    
    ## Task Directory Resolution
    
    1. Resolve the task directory from {{ params.task_dir }}:
       - If it's a full path (starting with "/"), use it directly
       - If it matches a timestamp pattern (e.g., "20250506120145"), find `notes/tasks/[timestamp]_*`
       - If it's a feature name (e.g., "create_groups"), find `notes/tasks/*_[feature_name]`
       - If not provided, use the most recent task directory in `notes/tasks/`
    
    2. If multiple matches or no matches found, ask the user to clarify
    
    ## Feature Completion Check
    
    3. Read the index.md file from the task directory
    4. Check if all tasks are marked as "completed"
    5. If not all tasks are completed:
       - Inform the user that some tasks are incomplete
       - Ask if they want to proceed with verification anyway
       - If they decline, suggest using the `/build` command to complete remaining tasks
    
    ## Verification Preparation
    
    6. Create a new Verification section in the index.md file
    7. Update the index.md with a verification entry:
       ```
       [{{ current_date }}] Starting comprehensive verification of the feature...
       ```
    
    ## Comprehensive Review
    
    8. Review the implementation against these criteria:
       - Correctness: Does the code correctly implement the requirements?
       - Completeness: Are all requirements addressed?
       - Security: Are there any security vulnerabilities?
       - Performance: Are there any potential performance issues?
       - Readability: Is the code easy to understand?
       - Maintainability: Will the code be easy to maintain?
       - Project Standards: Does the code follow project style guidelines?
       - Testing: Is there adequate test coverage?
       - Consistency: Is the implementation consistent across all tasks?
    
    9. Document findings in the Verification section in index.md:
       - List issues found by category
       - Suggest specific improvements
       - Note any missed requirements
    
    ## Testing
    
    10. Run all relevant tests:
        - Unit tests for the feature: `mix test`
        - Integration tests if applicable
        - Cucumber feature tests if applicable: `mix test test/features/`
        - Format checks with `mix format`
    
    11. Document test results in the index.md:
        - Tests that pass
        - Any test failures with details
        - Coverage statistics if available
    
    ## Improvements
    
    12. Implement critical fixes for any issues found:
        - Fix any failing tests
        - Address security concerns
        - Correct functionality issues
        - Add missing test coverage
        - Format code properly
    
    13. For non-critical improvements:
        - Document in the Verification section
        - Determine priority for later implementation
    
    ## Commit Changes
    
    14. If {{ params.commit }} is true and all tests pass:
        - Stage all changes
        - Prepare a detailed commit message following CLAUDE.md guidelines
        - Commit the changes
        - Document the commit in the index.md
    
    ## Final Status Update
    
    15. Update the index.md with verification results:
        ```
        ## Verification Results
        - Completed: [{{ current_date }}]
        - Status: [Passed/Failed/Passed with minor issues]
        - Issues Found: [number]
        - Issues Fixed: [number]
        - Overall Assessment: [brief assessment]
        ```
    
    ## Important Rules
    
    - Be thorough and systematic in your review
    - Prioritize issues: security > correctness > completeness > rest
    - Run all tests after making any changes
    - Always format code according to project standards
    - Focus on both technical correctness and maintainability
    - Verify against the original requirements
    - Document all issues found, even if not immediately fixed
    - Consider how the feature works as a whole, not just individual tasks
    
    ## Return Values
    
    Summarize the verification results, issues found, fixes applied, and provide recommendations for future improvements.
  </instructions>
</prompt>