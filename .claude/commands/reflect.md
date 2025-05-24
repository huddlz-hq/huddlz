<prompt>
  <params>
    task_dir # Path/identifier for task directory OR GitHub issue number
    issue # Optional GitHub parent issue number
  </params>

  <instructions>
    # Reflection Process
    
    This command analyzes completed work to extract learnings and improve future development.
    
    ## Workflow Detection
    
    1. Determine workflow mode:
       - If {{ params.issue }} is provided: GitHub issue mode
       - If {{ params.task_dir }} looks like a number: Check if it's a GitHub issue
       - Otherwise: File-based mode (legacy)
    
    ## GitHub Issue Mode
    
    If working with GitHub issues:
    
    1. Fetch parent issue and all sub-issues:
       ```
       gh issue view {{ params.issue }} --json title,body,comments
       gh issue list --label "issue-{{ params.issue }}" --json number,title,state,comments
       ```
    
    2. Extract Feature Log from parent issue comments
    
    3. Analyze all phases:
       - Planning insights from initial breakdown
       - Building challenges from progress updates
       - Course corrections marked with 🔄
       - Verification findings
    
    4. Update Feature Log with reflection:
       ```markdown
       ### Reflection Phase - [Current Date/Time]
       
       Analyzing complete feature implementation...
       ```
    
    ## File-Based Mode (Legacy)
    
    If using file-based workflow:
    
    1. Resolve task directory and analyze all task files
    2. Extract learnings from Session Logs and Progress sections
    
    ## Holistic Analysis
    
    Review the entire development process:
    
    1. **Requirements Evolution**:
       - What wasn't clear initially?
       - What requirements emerged during implementation?
       - Were acceptance criteria sufficient?
    
    2. **Task Breakdown Effectiveness**:
       - Were tasks appropriately sized?
       - Was the sequence logical?
       - Any unnecessary dependencies?
    
    3. **Implementation Insights**:
       - Course corrections and why they happened
       - Patterns that worked well
       - Anti-patterns to avoid
       - Performance considerations discovered
    
    4. **Testing Strategies**:
       - Test approaches that caught issues
       - Missing test scenarios discovered
       - BDD/TDD effectiveness
    
    5. **Process Observations**:
       - Communication gaps
       - Documentation needs
       - Tool effectiveness
    
    ## Learning Extraction
    
    Look for patterns in:
    - 🔄 COURSE CORRECTION markers
    - Multiple attempts at same problem
    - User feedback that changed approach
    - Quality gate failures and fixes
    
    Categorize learnings:
    ```markdown
    ## Key Learnings
    
    ### Technical Insights
    - [Specific technical pattern or approach]
    - [Performance optimization discovered]
    
    ### Process Improvements  
    - [Better way to break down similar features]
    - [Testing strategy that works well]
    
    ### Domain Knowledge
    - [Business logic understanding]
    - [User behavior insights]
    
    ### Tooling & Framework
    - [Ash Framework pattern]
    - [Phoenix LiveView approach]
    ```
    
    ## Global Knowledge Integration
    
    Update LEARNINGS.md with new insights:
    
    1. Read current LEARNINGS.md
    2. Identify appropriate categories
    3. Add new learnings with context:
       ```markdown
       ## [Category]
       
       ### [Learning Title]
       *From: Issue #{{ params.issue }} - [Feature Name]*
       
       [Detailed explanation with example]
       ```
    
    ## Process Evolution
    
    Based on patterns identified:
    
    1. Suggest command improvements:
       - Should planning ask different questions?
       - Should build enforce additional checks?
       - Should verify include new criteria?
    
    2. If suggesting changes, prepare proposals:
       ```markdown
       ## Proposed Process Improvements
       
       1. **Enhancement**: [What to change]
          **Rationale**: [Why based on this feature]
          **Implementation**: [How to update commands]
       ```
    
    3. Ask user for approval before modifying any commands
    
    ## Future Work Identification
    
    Create issues for:
    - Technical debt identified
    - Performance optimizations deferred  
    - Feature enhancements discovered
    - Refactoring opportunities
    
    ### GitHub Mode
    ```
    gh issue create \
      --title "[Type]: [Description]" \
      --body "[Details from reflection]" \
      --label "enhancement,from-reflection"
    ```
    
    ## Documentation Update
    
    ### GitHub Mode
    
    Final comment on parent issue:
    ```markdown
    ## Reflection Complete
    
    ### Summary
    Feature implemented successfully with [X] tasks completed.
    
    ### Key Learnings
    [Top 3-5 insights]
    
    ### Process Improvements
    [Suggested changes to workflow]
    
    ### Future Work
    - #[new-issue-1] - [Description]
    - #[new-issue-2] - [Description]
    
    LEARNINGS.md updated with new insights.
    ```
    
    ### File Mode
    
    Update index.md with reflection results
    
    ## Important Rules
    
    - Extract learnings from the entire journey, not just the end
    - Focus on patterns, not one-off issues
    - Make learnings actionable and specific
    - Always update LEARNINGS.md
    - Create follow-up issues for future work
    - Get approval before modifying commands
    
    ## Return Values
    
    - Key learnings summary
    - LEARNINGS.md updates made
    - Process improvements suggested
    - Future work issues created
  </instructions>
</prompt>