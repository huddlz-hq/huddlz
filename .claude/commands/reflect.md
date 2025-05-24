<prompt>
  <params>
    issue # GitHub issue number to reflect on
  </params>

  <instructions>
    # Reflection & Learning Extraction
    
    This command analyzes the development journey and extracts learnings.
    
    ## Context Gathering
    
    1. Validate issue parameter:
       - Must have {{ params.issue }} parameter
       - If missing, error with: "Please specify issue: /reflect issue=123"
    
    2. Read all relevant files:
       - `tasks/issue-{{ params.issue }}/index.md` - Requirements and plan
       - `tasks/issue-{{ params.issue }}/session.md` - Implementation journey
       - `tasks/issue-{{ params.issue }}/learnings.md` - Accumulated insights
       - All task files for specific challenges
    
    ## Analysis Process
    
    1. **Journey Analysis**:
       - Original plan vs actual implementation
       - Time estimates vs actual time
       - Unexpected challenges encountered
       - Course corrections made (🔄)
    
    2. **Pattern Recognition**:
       - Recurring challenges across tasks
       - Successful strategies that worked well
       - Anti-patterns to avoid
       - Reusable solutions discovered
    
    3. **Technical Insights**:
       - Framework-specific learnings
       - Performance considerations found
       - Testing strategies that proved effective
       - Integration patterns
    
    4. **Process Improvements**:
       - Workflow bottlenecks identified
       - Planning accuracy assessment
       - Task sizing effectiveness
       - Communication gaps
    
    ## Create Learnings Document
    
    Update or create `tasks/issue-[issue]/learnings.md`:
    
    ```markdown
    # Learnings from Issue #[issue]: [Title]
    
    **Completed**: [Date]
    **Duration**: [Planned vs Actual]
    **Complexity**: [Assessment]
    
    ## Key Insights
    
    ### 🎯 What Worked Well
    - [Success pattern 1 with example]
    - [Success pattern 2 with example]
    
    ### 🔄 Course Corrections
    [List all course corrections with lessons learned]
    
    ### ⚠️ Challenges & Solutions
    1. **Challenge**: [Description]
       **Solution**: [What worked]
       **Learning**: [Generalizable principle]
    
    ### 🚀 Reusable Patterns
    
    #### Pattern: [Name]
    **Context**: When to use this
    **Implementation**:
    ```elixir
    # Code example if applicable
    ```
    **Benefits**: Why this works
    
    ## Process Insights
    
    ### Planning Accuracy
    - Estimated tasks: [N]
    - Actual tasks: [N + additional]
    - Estimation accuracy: [X%]
    
    ### Time Analysis
    - Planned: [hours]
    - Actual: [hours]
    - Factors: [What affected timeline]
    
    ## Recommendations
    
    ### For Similar Features
    - [Specific recommendation 1]
    - [Specific recommendation 2]
    
    ### For Process Improvement
    - [Process change suggestion]
    - [Tool or command enhancement]
    
    ## Follow-up Items
    - [ ] [Improvement to make]
    - [ ] [Documentation to update]
    - [ ] [Pattern to document]
    ```
    
    ## Update Global Learnings
    
    If significant insights, append to `/LEARNINGS.md`:
    
    ```markdown
    
    ## Issue #[issue]: [Title] - [Date]
    
    ### Context
    [Brief description of what was built]
    
    ### Key Learnings
    [2-3 most important insights]
    
    ### Reusable Patterns
    [Any patterns worth sharing]
    
    See `tasks/issue-[issue]/learnings.md` for full details.
    ```
    
    ## Create Follow-up Tasks
    
    If improvements identified:
    
    1. For code improvements:
       - Create new GitHub issues
       - Link back to this implementation
    
    2. For documentation:
       - Note files to update
       - Create specific tasks
    
    3. For process improvements:
       - Update relevant command files
       - Document in CLAUDE.md
    
    ## Final GitHub Update
    
    Post completion summary:
    
    ```markdown
    ## ✨ Feature Complete & Reflected
    
    Successfully implemented [feature description].
    
    **Stats**:
    - Tasks completed: [N]
    - Commits: [N]
    - Tests added: [N]
    - Files changed: [N]
    
    **Key Learnings**:
    - [Top insight 1]
    - [Top insight 2]
    
    **Next Steps**:
    - [ ] Create PR
    - [ ] Address follow-up items
    
    Full learnings documented in codebase.
    ```
    
    ## Prepare for PR
    
    Generate PR description template:
    
    ```markdown
    ## Summary
    [What this PR accomplishes]
    
    Closes #[issue]
    
    ## Changes
    - [Major change 1]
    - [Major change 2]
    
    ## Testing
    - [How to test the feature]
    - [What scenarios were covered]
    
    ## Learnings
    [1-2 key insights from implementation]
    
    ## Screenshots
    [If applicable]
    ```
    
    Save to `tasks/issue-[issue]/pr-description.md`
    
    ## Return Message
    
    ```
    ✅ Reflection complete!
    
    Documented:
    - Key insights: [N]
    - Course corrections: [N]
    - Reusable patterns: [N]
    
    Created:
    - Local learnings file
    - Updated global LEARNINGS.md
    - PR description template
    
    Ready to create PR with:
    gh pr create --title "[Title]" --body-file tasks/issue-[issue]/pr-description.md
    ```
  </instructions>
</prompt>