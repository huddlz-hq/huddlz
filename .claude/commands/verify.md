<prompt>
  <params>
    task_dir # Path/identifier for task directory OR GitHub issue number  
    issue # Optional GitHub parent issue number
    commit # Whether to commit changes after verification (true/false, default false)
  </params>

  <instructions>
    # Verification Phase
    
    This command performs comprehensive review and testing of a completed feature implementation.
    
    ## Workflow Detection
    
    1. Determine workflow mode:
       - If {{ params.issue }} is provided: GitHub issue mode
       - If {{ params.task_dir }} looks like a number: Check if it's a GitHub issue
       - Otherwise: File-based mode (legacy)
    
    ## GitHub Issue Mode
    
    If working with GitHub issues:
    
    1. Fetch parent issue details:
       ```
       gh issue view {{ params.issue }} --json title,body,labels,state
       ```
    
    2. List all sub-issues:
       ```
       gh issue list --label "issue-{{ params.issue }}" --json number,title,state
       ```
    
    3. Check completion status:
       - Count closed vs open sub-issues
       - If not all closed, ask if user wants to proceed anyway
    
    4. Update Feature Log on parent issue:
       ```markdown
       ### Verification Phase - [Current Date/Time]
       
       Starting comprehensive review of feature implementation...
       Sub-issues completed: [X/Y]
       ```
    
    ## File-Based Mode (Legacy)
    
    If using file-based workflow:
    
    1. Resolve task directory and check task completion status
    2. Proceed with file-based verification as before
    
    ## Comprehensive Review
    
    Review the implementation against these criteria:
    
    1. **Requirements Coverage**:
       - Check each requirement from parent issue
       - Verify all acceptance criteria are met
       - Note any missing functionality
    
    2. **Code Quality**:
       - Readability and maintainability
       - Follows project patterns and conventions
       - Proper error handling
       - No code smells or anti-patterns
    
    3. **Security**:
       - No hardcoded secrets
       - Proper input validation
       - Authorization checks in place
       - SQL injection prevention
    
    4. **Performance**:
       - No N+1 queries
       - Efficient algorithms
       - Appropriate caching
    
    5. **Testing**:
       - Adequate test coverage
       - Tests follow BDD/TDD principles
       - Edge cases covered
    
    ## Quality Gates (Re-run)
    
    Run comprehensive quality checks:
    
    ```bash
    # Format check
    mix format --check-formatted
    
    # All tests
    mix test
    
    # Static analysis  
    mix credo --strict
    
    # Feature tests
    mix test test/features/
    ```
    
    Document results:
    ```markdown
    ## Quality Gate Results
    - Format: ✅ Clean
    - Tests: ✅ 127 passed, 0 failed
    - Credo: ✅ No issues
    - Features: ✅ All scenarios passing
    ```
    
    ## Integration Testing
    
    Beyond unit tests, verify:
    - Feature works end-to-end
    - No regressions in existing functionality
    - UI components render correctly
    - API endpoints respond as expected
    
    ## Issue Documentation
    
    ### GitHub Mode
    
    Create verification comment on parent issue:
    ```markdown
    ## Verification Complete
    
    ### Coverage
    ✅ All requirements implemented
    ✅ All sub-issues completed
    
    ### Quality
    - Code Review: [Pass/Issues Found]
    - Security: [Pass/Concerns]
    - Performance: [Acceptable/Needs Work]
    
    ### Testing
    - Unit Tests: [X passed]
    - Feature Tests: [Y passed]
    - Manual Testing: [Completed/Issues]
    
    ### Issues Found & Fixed
    1. [Issue description] - ✅ Fixed
    2. [Issue description] - 📝 Documented for later
    
    ### Recommendations
    - [Future improvements]
    - [Technical debt to address]
    ```
    
    ### File Mode
    
    Update index.md with verification results
    
    ## Improvements
    
    If issues found:
    
    1. **Critical** (must fix now):
       - Security vulnerabilities
       - Failing tests
       - Broken functionality
       - Data corruption risks
    
    2. **Important** (should fix):
       - Performance issues
       - Code quality problems
       - Missing tests
    
    3. **Minor** (can defer):
       - Style improvements
       - Refactoring opportunities
       - Documentation updates
    
    Fix critical issues immediately and re-run quality gates.
    
    ## Commit Changes
    
    If {{ params.commit }} is true and all tests pass:
    
    1. Stage all changes
    2. Create commit message:
       ```
       feat(scope): implement [feature name]
       
       - [Key change 1]
       - [Key change 2]
       
       Closes #{{ params.issue }}
       ```
    3. Commit changes
    4. Push to feature branch
    
    ## Learning Capture
    
    Document verification insights:
    - Gaps in original requirements
    - Testing strategies that worked well
    - Patterns to use in future features
    - Process improvements identified
    
    ## Return Values
    
    - Verification status (Passed/Failed/Passed with issues)
    - Quality gate results
    - Issues found and fixes applied
    - Recommendations for future work
    - Commit hash (if committed)
  </instructions>
</prompt>