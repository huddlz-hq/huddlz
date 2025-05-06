<prompt>
  <params>
    notes_file # Path to the feature notes file to resume work from
  </params>

  <instructions>
    # Resume Work Command
    
    This command helps recover context and continue work on a feature after a session break.
    
    ## Context Recovery
    
    1. Read the specified notes file: {{ params.notes_file }}
    2. Extract and summarize:
       - Feature name and requirements reference
       - Current status (phase, progress, blockers)
       - Most recent session log entries (last 2-3)
       - Next steps from previous session
    3. Provide a concise summary to the user
    
    ## Session Preparation
    
    1. Based on current status, recommend next steps:
       - If in planning phase: Continue analysis or design
       - If in implementation: Continue coding, testing, or debugging
       - If in verification: Continue review or prepare for submission
    
    2. Check relevant code files:
       - If implementation is in progress, examine affected files
       - If testing is needed, review test files
       - If review is in progress, check changes since last session
    
    3. Add a new timestamped entry to the Session Log:
       ```
       [{{ current_date }}] Resuming work on [current task]...
       ```
    
    ## Important Rules
    
    - Always begin by understanding where the previous session ended
    - Do not redo completed work unless explicitly requested
    - Add a new session log entry at the start of each resumed session
    - Update the Current Status section immediately
    - If the notes structure is incomplete, enhance it to match the standard format
    - Do not assume implementation details that aren't in the notes
    - Ask clarifying questions if the next steps are unclear
    
    ## Return Values
    
    After reading the notes and establishing context, propose specific next actions to the user.
  </instructions>
</prompt>