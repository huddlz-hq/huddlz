<prompt>
  <params>
    notes_file # Path to the feature notes file
    commit # Whether to commit changes after verification (true/false, default false)
  </params>

  <instructions>
    # Verification Phase
    
    This command handles review, testing, and quality assurance of implemented code.
    
    ## Preparation
    
    1. Read the notes file: {{ params.notes_file }}
    2. Update the Session Log with a new entry:
       ```
       [{{ current_date }}] Starting verification and review...
       ```
    3. Update the Current Status section:
       ```
       - Phase: Verification
       - Progress: X% (estimate based on completed work)
       - Current task: Verification and review
       - Blockers: Any known issues
       ```
    
    ## Comprehensive Review
    
    4. Review the implementation against these criteria:
       - Correctness: Does the code correctly implement the requirements?
       - Completeness: Are all requirements addressed?
       - Security: Are there any security vulnerabilities?
       - Performance: Are there any potential performance issues?
       - Readability: Is the code easy to understand?
       - Maintainability: Will the code be easy to maintain?
       - Project Standards: Does the code follow project style guidelines?
       - Testing: Is there adequate test coverage?
    
    5. Document findings in a "Verification" section in {{ params.notes_file }}:
       - List issues found by category
       - Suggest specific improvements
       - Note any missed requirements
    
    ## Testing
    
    6. Run all relevant tests:
       - Unit tests for the feature
       - Integration tests if applicable
       - Cucumber feature tests if applicable
       - Format checks with `mix format`
    
    7. Document test results in the Session Log:
       - Tests that pass
       - Any test failures with details
       - Coverage statistics if available
    
    ## Improvements
    
    8. Implement critical fixes for any issues found:
       - Fix any failing tests
       - Address security concerns
       - Correct functionality issues
       - Add missing test coverage
       - Format code properly
    
    9. For non-critical improvements:
       - Document in the Verification section
       - Determine priority for later implementation
    
    ## Commit Changes
    
    10. If {{ params.commit }} is true and all tests pass:
        - Stage all changes
        - Prepare a detailed commit message
        - Commit the changes to the feature branch
        - Document the commit in the Session Log
    
    ## Important Rules
    
    - Be thorough and systematic in your review
    - Prioritize issues: security > correctness > completeness > rest
    - Run all tests after making any changes
    - Always format code according to project standards
    - Focus on both technical correctness and maintainability
    - Verify against the original requirements document
    - Document all issues found, even if not immediately fixed
    
    ## Return Values
    
    Summarize the verification results, issues found, fixes applied, and recommendations.
  </instructions>
</prompt>