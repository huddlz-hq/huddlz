<prompt>
  <params>
    fix # Whether to automatically fix issues (true/false, default true)
  </params>

  <instructions>
    # Review Code Quality
    
    This command performs comprehensive quality checks on the current work.
    
    ## Code Formatting
    
    1. Check formatting:
       ```
       mix format --check-formatted
       ```
       
    2. If not formatted and {{ params.fix }} is true:
       ```
       mix format
       ```
       - Commit formatting changes if any
    
    ## Static Analysis
    
    3. Run Credo analysis:
       ```
       mix credo --strict
       ```
       - Document any warnings or issues
       - Suggest fixes for common problems
    
    ## Testing
    
    4. Run all tests:
       ```
       mix test
       ```
       - Note any failures
       - Check test coverage if available
    
    5. Run feature tests:
       ```
       mix test test/features/
       ```
       - Ensure behavior tests pass
    
    ## Code Review Checklist
    
    6. Automated checks for common issues:
       - Unused variables or functions
       - Missing documentation
       - Complex functions that should be refactored
       - Security concerns (hardcoded secrets, SQL injection risks)
       - Performance issues (N+1 queries, inefficient algorithms)
    
    ## Dependency Check
    
    7. Verify dependencies:
       ```
       mix deps.get
       mix deps.compile
       ```
       - Ensure no missing dependencies
       - Check for security advisories
    
    ## Documentation Review
    
    8. Check for required documentation:
       - Public functions have @doc tags
       - Modules have @moduledoc
       - Complex logic is commented
       - README is updated if needed
    
    ## Issue Summary
    
    9. Create summary report:
       ```
       ## Review Summary
       
       ### Formatting
       - Status: [Passed/Fixed/Failed]
       - Files formatted: [count]
       
       ### Static Analysis (Credo)
       - Status: [Passed/Warnings]
       - Issues found: [list]
       
       ### Tests
       - Status: [Passed/Failed]
       - Test count: [total]
       - Failures: [count]
       
       ### Documentation
       - Missing @doc: [count]
       - Missing @moduledoc: [count]
       
       ### Recommendations
       - [Priority fixes needed]
       ```
    
    ## Auto-Fix Implementation
    
    10. If {{ params.fix }} is true and issues found:
        - Apply safe automatic fixes
        - Commit each type of fix separately:
          - `style: apply code formatting`
          - `docs: add missing documentation`
          - `refactor: address credo warnings`
    
    ## Return Values
    
    Return the review summary and status (ready for PR or needs fixes)
  </instructions>
</prompt>