<prompt>
  <params>
    issue # GitHub issue number to work on
  </params>

  <instructions>
    # Start Work on GitHub Issue
    
    This command initializes work on a GitHub issue, setting up the development environment and documentation.
    
    ## Issue Retrieval
    
    1. Use gh CLI to fetch issue details:
       ```
       gh issue view {{ params.issue }} --json title,body,labels,assignees,milestone
       ```
    
    2. Extract key information:
       - Issue title and description
       - Labels (feature, bug, enhancement, etc.)
       - Acceptance criteria from description
       - Related issues or context
    
    ## Branch Setup
    
    3. Create feature branch:
       - Generate branch name: `issue-{{ params.issue }}-[short-description]`
       - Create and checkout: `git checkout -b [branch-name]`
       - Set upstream: `git push -u origin [branch-name]`
    
    ## Session Documentation
    
    4. Create session note: `notes/session-[YYYYMMDD]-issue-{{ params.issue }}.md`
       ```markdown
       # Session: Issue #{{ params.issue }} - [Issue Title]
       Date: [Current Date]
       
       ## Issue Details
       - Number: #{{ params.issue }}
       - Title: [Issue Title]
       - Type: [from labels]
       - Branch: [branch-name]
       
       ## Requirements
       [Extracted from issue body]
       
       ## Acceptance Criteria
       [Extracted from issue body]
       
       ## Implementation Plan
       [To be filled during exploration]
       
       ## Progress Log
       - [timestamp] Started work on issue #{{ params.issue }}
       - [timestamp] Created feature branch: [branch-name]
       
       ## Key Decisions
       [Document important choices]
       
       ## Testing Notes
       [Track test scenarios]
       ```
    
    ## Exploration Phase
    
    5. Research and understand:
       - Search for related code patterns
       - Identify files that need modification
       - Review similar implementations
       - Check test patterns
    
    6. Update session note with findings:
       - Add relevant file paths
       - Document existing patterns to follow
       - Note potential challenges
    
    ## Planning Summary
    
    7. Create brief implementation plan in session note:
       - High-level approach
       - Key files to modify
       - Testing strategy
       - No complex task decomposition
    
    ## Return Values
    
    Return:
    - Issue summary
    - Branch name created
    - Session note path
    - Next steps for implementation
  </instructions>
</prompt>