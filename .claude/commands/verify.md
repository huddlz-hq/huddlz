<prompt>
  <params>
    issue # GitHub parent issue number to verify
  </params>

  <instructions>
    # Verification Phase
    
    This command performs comprehensive review and testing of a completed feature implementation.
    
    ## Feature Status Check
    
    1. Fetch parent issue and all sub-issues:
       ```
       gh issue view {{ params.issue }} --json title,body,state,labels
       gh issue list --label "parent-{{ params.issue }}" --json number,title,state
       ```
    
    2. Verify completion status:
       - Count closed vs open sub-issues
       - List any incomplete tasks
       - If not all closed, ask user if they want to proceed
    
    3. Update Feature Log:
       ```markdown
       ### Verification Phase - [Current Date/Time]
       
       Starting comprehensive review of feature implementation.
       Sub-issues completed: [X] of [Y]
       ```
    
    ## Requirements Review
    
    1. Extract original requirements from parent issue
    2. Review each requirement against implementation:
       - ✅ Fully implemented
       - ⚠️ Partially implemented
       - ❌ Not implemented
    
    3. Check acceptance criteria:
       - Each criterion met?
       - Edge cases handled?
       - Performance requirements satisfied?
    
    ## Code Quality Review
    
    Analyze the implementation for:
    
    1. **Architecture & Design**:
       - Follows project patterns?
       - Proper separation of concerns?
       - Ash Framework best practices?
    
    2. **Code Quality**:
       - Readable and maintainable?
       - DRY principles followed?
       - Proper error handling?
       - No code smells?
    
    3. **Security**:
       - No hardcoded secrets
       - Proper authorization checks
       - Input validation in place
       - SQL injection prevention
    
    4. **Performance**:
       - No N+1 queries
       - Efficient database access
       - Appropriate indexes
       - Caching where needed
    
    5. **Testing**:
       - Adequate test coverage
       - Tests follow BDD/TDD style
       - Edge cases covered
       - Tests are maintainable
    
    ## Quality Gates (Comprehensive)
    
    Run full test suite:
    ```bash
    # Clean build
    mix clean && mix deps.get && mix compile
    
    # Format check
    mix format --check-formatted
    
    # All tests with coverage
    mix test --cover
    
    # Static analysis
    mix credo --strict
    
    # Feature tests specifically
    mix test test/features/
    
    # Check for warnings
    mix compile --warnings-as-errors
    ```
    
    Document results:
    ```markdown
    ## Quality Gate Results
    
    ✅ **Build**: Clean compilation
    ✅ **Format**: No changes needed
    ✅ **Tests**: [X] passed, 0 failed
    ✅ **Coverage**: [X]% (target: 80%)
    ✅ **Credo**: No issues
    ✅ **Features**: All scenarios passing
    ✅ **Warnings**: None
    ```
    
    ## Integration Testing
    
    Beyond unit tests:
    1. Run the application: `mix phx.server`
    2. Test the feature end-to-end
    3. Verify UI components work correctly
    4. Check for regressions in related features
    5. Test with different user roles
    
    ## Issues Found
    
    Categorize any issues:
    
    1. **🔴 Critical** (must fix now):
       - Security vulnerabilities
       - Data corruption risks
       - Broken functionality
       - Failing tests
    
    2. **🟡 Important** (should fix):
       - Performance problems
       - Missing tests
       - Code quality issues
       - Minor bugs
    
    3. **🟢 Minor** (can defer):
       - Style improvements
       - Refactoring opportunities
       - Documentation gaps
    
    If critical issues found:
    - Fix immediately
    - Re-run all quality gates
    - Document fixes in Feature Log
    
    ## Documentation Review
    
    Check for:
    - Updated README if needed
    - API documentation current
    - Code comments where necessary
    - LEARNINGS.md candidates
    
    ## Verification Summary
    
    Post comprehensive summary to parent issue:
    ```markdown
    ## Verification Complete ✅
    
    ### Requirements Coverage
    - [X] of [Y] requirements fully implemented
    - [List any gaps]
    
    ### Quality Assessment
    **Code Quality**: Excellent/Good/Needs Work
    **Test Coverage**: [X]%
    **Performance**: Acceptable/Optimized
    **Security**: Passed all checks
    
    ### Quality Gates
    All gates passing:
    - Tests: [X] passed
    - Format: Clean
    - Credo: No issues
    - Coverage: [X]%
    
    ### Issues Found & Resolution
    🔴 Critical: [0] - All resolved
    🟡 Important: [X] - [Status]
    🟢 Minor: [X] - Documented for later
    
    ### Integration Testing
    - Feature works end-to-end ✅
    - No regressions found ✅
    - UI components render correctly ✅
    
    ### Recommendations
    1. [Future enhancements]
    2. [Technical debt to address]
    3. [Process improvements]
    
    **Feature is ready for production.** 🚀
    ```
    
    ## Learning Extraction
    
    Review all sub-issue comments for:
    - 🔄 Course corrections
    - Testing strategies that worked
    - Performance optimizations found
    - Patterns to document
    
    Add to Feature Log:
    ```markdown
    ### Key Learnings from Verification
    - [Important insights]
    - [Patterns validated]
    - [Areas for improvement]
    ```
    
    ## Next Steps
    
    1. If all verified successfully:
       ```
       Feature #{{ params.issue }} verified successfully!
       All quality gates passed.
       
       Ready to:
       1. Create PR for review
       2. Deploy to staging
       3. Run `/reflect issue={{ params.issue }}` to capture learnings
       ```
    
    2. If issues remain:
       ```
       Verification found [X] issues that need attention.
       Please review the verification summary.
       
       Fix critical issues before proceeding.
       ```
    
    ## Important Rules
    
    - Be thorough and systematic
    - Run ALL quality gates
    - Test the actual user experience
    - Document all findings
    - Don't skip security checks
    - Verify against original requirements
    
    ## Return Values
    
    - Feature: #{{ params.issue }}
    - Status: Passed/Failed/Passed with issues
    - Quality gates: [Results]
    - Issues found: [Count by severity]
    - Ready for: PR/Fixes needed/Deployment
  </instructions>
</prompt>