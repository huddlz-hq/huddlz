<prompt>
  <params>
    issue # GitHub issue number to sync
    message # Optional: Custom sync message
  </params>

  <instructions>
    # GitHub Sync
    
    This command syncs local progress back to the GitHub issue.
    
    ## Validate Parameters
    
    1. Validate issue parameter:
       - Must have {{ params.issue }} parameter
       - If missing, error with: "Please specify issue: /sync issue=123"
    
    2. Verify task directory exists:
       ```
       tasks/issue-{{ params.issue }}/
       ```
       If not found: "No task structure found for issue {{ params.issue }}. Nothing to sync."
    
    ## Gather Progress Information
    
    1. Read index.md to get:
       - Overall progress (checked items)
       - Current status
       - Last sync time
    
    2. Read session.md to extract:
       - Recent accomplishments
       - Key learnings
       - Course corrections (🔄)
    
    3. Check task files for:
       - Completed tasks since last sync
       - Currently in-progress tasks
       - Remaining tasks
    
    ## Generate Sync Message
    
    Create a concise update for GitHub:
    
    ```markdown
    ## 📊 Progress Update
    
    **Status**: [X of Y] tasks complete
    **Current**: [Current task name or "All tasks complete"]
    
    ### Recently Completed
    - ✅ Task [N]: [Name] - [Brief outcome]
    [List tasks completed since last sync]
    
    ### Key Insights
    [Any significant learnings or course corrections]
    
    ### Next Steps
    [What's coming next]
    
    {{ params.message if provided }}
    ```
    
    ## Post Update
    
    1. Post comment to GitHub issue:
       ```
       gh issue comment {{ issue }} --body "[sync message]"
       ```
    
    2. Update index.md:
       - Update "Last sync" timestamp
       - Set "Next sync" expectation
    
    ## Sync Triggers
    
    Suggest syncing when:
    - Task completed
    - Significant course correction
    - End of work session
    - Before requesting user input
    - Major milestone reached
    
    ## Return Message
    
    ```
    ✅ Synced progress to issue #{{ issue }}
    
    Status: [X/Y] tasks complete
    Last sync: [time]
    ```
  </instructions>
</prompt>