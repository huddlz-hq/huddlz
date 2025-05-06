<prompt>
  <params>
    description # Brief description of the bug or quick fix
    issue_id # Optional identifier for tracking (e.g., "bug-123" or just a descriptive slug)
  </params>

  <instructions>
    # Quick Fix Workflow
    
    This command provides a lightweight process for bug fixes and small changes that don't warrant a full requirements document.
    
    ## Initial Setup
    
    1. Create a notes file for this quick fix:
       - Use the format: `notes/quickfix-{{ params.issue_id || "untracked" }}.md`
       - If issue_id is not provided, generate a slug from the description
    
    2. Initialize the notes file with basic structure:
    
    ```markdown
    # Quick Fix: {{ params.description }}
    
    ## Summary
    {{ params.description }}
    
    ## Current Status
    - Phase: Planning
    - Progress: 0%
    - Blockers: None
    
    ## Analysis
    [Analysis of the issue will be added here]
    
    ## Implementation
    [Implementation details will be added here]
    
    ## Session Log
    [{{ current_date }}] Started quick fix process...
    
    ## Learnings
    [Insights will be captured here]
    ```
    
    ## Analysis Phase
    
    3. Analyze the issue:
       - Identify what's broken
       - Determine root cause if possible
       - Document investigation steps
       - Specify minimal fix requirements
    
    4. Update the notes file:
       - Add analysis to the Analysis section
       - Update session log
       - Update current status
    
    ## Implementation Phase
    
    5. Implement the fix:
       - Create a branch if needed (format: `fix/quickfix-{{ params.issue_id || "untracked" }}`)
       - Make minimal changes to address the issue
       - Test the fix thoroughly
       - Document the implementation in the notes
    
    6. Update the notes file:
       - Add implementation details to the Implementation section
       - Update session log
       - Update current status
    
    ## Reflection Phase
    
    7. After completing the fix:
       - Document any challenges encountered
       - Note what worked well or didn't
       - Capture potential future improvements
       - Update the Learnings section
    
    ## Important Rules
    
    - Keep changes minimal and focused
    - Always test thoroughly
    - Document what was learned, even for small fixes
    - Update session log with timestamped entries
    - Consider whether the issue indicates a larger problem
    
    ## Return Values
    
    Return the path to the created notes file for use with other commands like `/reflect`.
  </instructions>
</prompt>