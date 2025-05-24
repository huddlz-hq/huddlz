<prompt>
  <params>
    issue # GitHub issue number to verify
  </params>

  <instructions>
    # Verification Phase
    
    This command performs comprehensive verification of the implemented feature.
    
    ## Context Discovery
    
    1. Validate issue parameter:
       - Must have {{ params.issue }} parameter
       - If missing, error with: "Please specify issue: /verify issue=123"
       
    2. Verify task directory exists:
       ```
       tasks/issue-{{ params.issue }}/
       ```
       If not found: "No task structure found for issue {{ params.issue }}. Nothing to verify."
    
    3. Check implementation status:
       - Read all task files in `tasks/issue-{{ params.issue }}/tasks/`
       - Ensure all have `**Status**: completed`
       - If any pending/in_progress, list them and stop
    
    ## Verification Process
    
    1. **Code Quality Verification**:
       ```bash
       # Run all quality gates
       mix format --check-formatted
       mix test
       mix credo --strict
       mix test test/features/
       ```
       
       Document any issues found
    
    2. **Requirements Review**:
       - Read original requirements from index.md
       - Check each success criteria
       - Verify acceptance criteria for each task
    
    3. **Integration Testing**:
       - Start Phoenix server
       - Test the complete user flow
       - Verify all components work together
       - Check for edge cases
    
    4. **Documentation Review**:
       - Ensure any new components are documented
       - Check for outdated documentation
       - Verify examples work
    
    ## Create Verification Report
    
    Append to session.md:
    
    ```markdown
    
    ## Verification Phase - [Date/Time]
    
    ### Quality Gates
    - Format: [✅ Pass / ❌ Issues found]
    - Tests: [X passing, Y failing]
    - Credo: [✅ Clean / ❌ X issues]
    - Features: [✅ All passing / ❌ X scenarios failing]
    
    ### Requirements Verification
    
    #### Success Criteria
    - [ ] [Criterion 1]: [Status and notes]
    - [ ] [Criterion 2]: [Status and notes]
    
    #### User Flow Testing
    1. [Test scenario 1]: [Result]
    2. [Test scenario 2]: [Result]
    
    ### Issues Found
    
    #### 🔴 Critical (Must fix)
    - [Issue description and location]
    
    #### 🟡 Important (Should fix)
    - [Issue description and location]
    
    #### 🟢 Minor (Nice to fix)
    - [Issue description and location]
    
    ### Verification Summary
    [Overall assessment and recommendation]
    ```
    
    ## Handle Verification Results
    
    1. **If all checks pass**:
       - Update index.md with verification timestamp
       - Prepare for PR creation
       - Suggest next step: `/reflect`
    
    2. **If issues found**:
       - Create fix tasks in tasks directory
       - Update task status tracking
       - Provide clear remediation plan
    
    ## Fix Task Creation
    
    If issues need fixing, create `tasks/issue-[issue]/tasks/0X-fix-[description].md`:
    
    ```markdown
    # Fix Task: [Description]
    
    **Status**: pending
    **Type**: fix
    **Severity**: [critical/important/minor]
    
    ## Issue Description
    [What's wrong and why it needs fixing]
    
    ## Fix Approach
    [How to fix the issue]
    
    ## Verification
    [How to verify the fix works]
    ```
    
    ## GitHub Sync
    
    Post verification summary:
    
    ```markdown
    ## ✅ Verification Complete
    
    All implementation tasks have been completed and verified.
    
    **Quality Gates**: [Status]
    **Requirements**: [X of Y] criteria met
    **Integration**: [Status]
    
    [If issues found, list critical ones]
    
    Ready for final review and reflection.
    ```
    
    ## Return Message
    
    Based on results:
    
    ```
    # If passed:
    ✅ Verification complete! All checks passed.
    
    Quality gates: All green
    Requirements: Fully satisfied
    Integration: Working as expected
    
    Ready to proceed with: /reflect
    
    # If issues:
    ⚠️ Verification found [N] issues to address:
    
    Critical: [X] issues (must fix)
    Important: [Y] issues (should fix)
    Minor: [Z] issues (optional)
    
    Created fix tasks. Start with:
    /build task=[next task number]
    ```
  </instructions>
</prompt>