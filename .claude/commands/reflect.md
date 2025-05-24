<prompt>
  <params>
    issue # GitHub parent issue number to reflect on
  </params>

  <instructions>
    # Reflection Process
    
    This command analyzes the complete development journey to extract learnings and improve future work.
    
    ## Data Collection
    
    1. Fetch complete issue history:
       ```
       gh issue view {{ params.issue }} --json title,body,comments,state
       gh issue list --label "parent-{{ params.issue }}" --json number,title,state,body,comments
       ```
    
    2. Extract Feature Log from parent issue
       - Planning phase insights
       - Building phase progress
       - Verification findings
       - All course corrections (🔄)
    
    3. Analyze sub-issue histories:
       - Progress updates
       - Challenges documented
       - Solutions found
       - Time taken per task
    
    ## Journey Analysis
    
    Review the entire development process:
    
    ### 1. Requirements Evolution
    ```markdown
    ## Requirements Analysis
    
    **Initial Understanding:**
    - [What we thought we were building]
    
    **Discovered Requirements:**
    - [What emerged during planning]
    - [What emerged during building]
    
    **Gaps Identified:**
    - [What was missed initially]
    - [Why it was missed]
    ```
    
    ### 2. Planning Effectiveness
    ```markdown
    ## Planning Assessment
    
    **Task Breakdown:**
    - Total tasks created: [X]
    - Task sizing accuracy: [Good/Needs work]
    - Dependency management: [Effective/Issues]
    
    **What Worked:**
    - [Successful strategies]
    
    **What Didn't:**
    - [Planning gaps]
    - [Over/under estimation]
    ```
    
    ### 3. Implementation Insights
    
    Look for patterns in:
    - 🔄 Course corrections
    - Multiple attempts at same problem
    - Quality gate failures
    - Performance discoveries
    
    ```markdown
    ## Implementation Learnings
    
    **Technical Patterns:**
    - [Patterns that worked well]
    - [Anti-patterns to avoid]
    
    **Course Corrections:**
    [List each with lesson learned]
    
    **Testing Insights:**
    - [Effective test strategies]
    - [Missing test scenarios]
    ```
    
    ### 4. Process Observations
    ```markdown
    ## Process Insights
    
    **Workflow Effectiveness:**
    - [What helped productivity]
    - [What caused delays]
    
    **Communication:**
    - [Clear areas]
    - [Confusion points]
    
    **Tools & Automation:**
    - [What worked well]
    - [What needs improvement]
    ```
    
    ## Learning Synthesis
    
    Categorize key learnings:
    
    ```markdown
    ## Key Learnings
    
    ### Technical Insights
    1. **[Pattern/Approach Name]**
       - Context: [When to use]
       - Example: [From this feature]
       - Benefit: [Why it works]
    
    ### Ash Framework Patterns
    1. **[Specific Ash pattern]**
       - Use case: [When applicable]
       - Implementation: [How to do it]
    
    ### Testing Strategies
    1. **[Test approach]**
       - Scenario: [When to apply]
       - Example: [From this feature]
    
    ### Process Improvements
    1. **[Improvement idea]**
       - Current: [What we do now]
       - Proposed: [Better approach]
       - Rationale: [Why it's better]
    ```
    
    ## LEARNINGS.md Update
    
    1. Read current LEARNINGS.md
    2. Identify appropriate sections
    3. Add new insights with context:
    
    ```markdown
    ### [Learning Title]
    *From: Issue #{{ params.issue }} - [Feature Name]*
    *Date: [Current Date]*
    
    **Context:**
    [Situation where this applies]
    
    **Discovery:**
    [What we learned]
    
    **Application:**
    [How to use this knowledge]
    
    **Example:**
    ```elixir
    # Code example if applicable
    ```
    ```
    
    ## Process Evolution
    
    Based on learnings, suggest improvements:
    
    ```markdown
    ## Proposed Process Improvements
    
    1. **Planning Phase Enhancement**
       - Add question: [New question to ask]
       - Rationale: [Why based on this feature]
    
    2. **Build Command Update**
       - Add check: [New validation]
       - Prevents: [Issue it would avoid]
    
    3. **Documentation Template**
       - Add section: [What's missing]
       - Benefit: [How it helps]
    ```
    
    Ask for approval before implementing any command changes.
    
    ## Future Work
    
    Create follow-up issues:
    
    ```bash
    # Technical debt
    gh issue create \
      --title "refactor: [description]" \
      --body "Identified during #{{ params.issue }}..." \
      --label "tech-debt,enhancement"
    
    # Feature enhancements  
    gh issue create \
      --title "feat: [description]" \
      --body "Enhancement opportunity from #{{ params.issue }}..." \
      --label "enhancement"
    
    # Documentation needs
    gh issue create \
      --title "docs: [description]" \
      --body "Documentation gap found in #{{ params.issue }}..." \
      --label "documentation"
    ```
    
    ## Reflection Summary
    
    Post final reflection to parent issue:
    
    ```markdown
    ## Reflection Complete 📚
    
    ### Feature Summary
    - Started: [Date from first comment]
    - Completed: [Date]
    - Tasks: [X] sub-issues
    - Commits: [Y] total
    
    ### Key Learnings
    
    **Technical:**
    1. [Most important technical insight]
    2. [Second insight]
    
    **Process:**
    1. [Most important process learning]
    2. [Second learning]
    
    **Domain:**
    1. [Business logic understanding]
    
    ### Improvements Made
    - Updated LEARNINGS.md with [X] new insights
    - Created [Y] follow-up issues
    - Proposed [Z] process improvements
    
    ### Metrics
    - Course corrections: [Count of 🔄]
    - Quality gate failures: [Count]
    - Time per task: [Average]
    
    ### Next Features Will Benefit From
    1. [Specific improvement]
    2. [Specific pattern]
    3. [Specific approach]
    
    **Thank you for the learning opportunity!** 🎉
    ```
    
    ## Close the Loop
    
    1. Ensure LEARNINGS.md is updated
    2. Verify follow-up issues created
    3. Confirm process improvements documented
    4. Close parent issue if appropriate
    
    ## Important Rules
    
    - Extract learnings from entire journey
    - Focus on patterns, not one-offs
    - Make learnings actionable
    - Always update LEARNINGS.md
    - Create issues for future work
    - Get approval for process changes
    - Be specific with examples
    
    ## Return Values
    
    - Feature reflected: #{{ params.issue }}
    - Key learnings: [Count]
    - LEARNINGS.md sections updated: [List]
    - Follow-up issues created: [Numbers]
    - Process improvements proposed: [Count]
  </instructions>
</prompt>