<prompt>
  <params>
    issue # GitHub issue number to plan from
  </params>

  <instructions>
    # Task Decomposition Planning
    
    This command analyzes a GitHub issue and creates a local file structure for managing implementation.
    
    ## Initial Setup
    
    1. Fetch issue details using gh CLI:
       ```
       gh issue view {{ params.issue }} --json title,body,labels,assignees,milestone
       ```
    
    2. Extract requirements from issue:
       - Parse issue body for requirements
       - Identify acceptance criteria
       - Note any technical specifications
       - Create sanitized title for directory name
    
    3. Create local task structure:
       ```
       tasks/issue-{{ params.issue }}/
       ├── index.md          # Requirements and plan
       ├── session.md        # Implementation notes
       ├── tasks/            # Individual task files
       └── learnings.md      # Accumulated insights
       ```
    
    4. Create feature branch:
       ```
       git checkout -b feature/issue-{{ params.issue }}-[short-description]
       ```
    
    ## Requirements Analysis
    
    **CRITICAL: Do NOT proceed with planning until completing thorough discovery with the user!**
    
    Conduct interactive requirements analysis with PM mindset:
    
    1. **Initial Questions** (MUST ask the user):
       - What problem does this solve for users?
       - Who are the primary users?
       - What specific actions should users be able to perform?
       - What are the constraints or limitations?
       - How does this integrate with existing features?
    
    2. **Deep Dive** (based on initial answers):
       - Data requirements: What information needs to be stored/displayed?
       - User flows: Walk through the typical user journey
       - Edge cases: What happens in unexpected scenarios?
       - Access control: Who can perform these actions?
       - Performance: Any specific performance requirements?
    
    3. **Continue dialogue until you have**:
       - Clear scope boundaries agreed with user
       - Specific functional requirements confirmed
       - Non-functional requirements understood
       - Measurable success criteria defined
       - User has explicitly approved the understanding
    
    **Only after user confirms understanding is complete, proceed to create files!**
    
    ## Create Index File
    
    Write `tasks/issue-{{ params.issue }}/index.md`:
    
    ```markdown
    # Issue #{{ params.issue }}: [Issue Title]
    
    **GitHub Issue**: [Link to issue]
    **Created**: [Current Date/Time]
    **Branch**: feature/issue-{{ params.issue }}-[description]
    
    ## Original Requirements
    [Copy issue body here]
    
    ## Requirements Analysis
    
    ### User Problem
    [What problem this solves]
    
    ### Target Users
    [Who will use this feature]
    
    ### Success Criteria
    - [ ] [Measurable outcome 1]
    - [ ] [Measurable outcome 2]
    
    ### Technical Approach
    [High-level implementation strategy]
    
    ## Task Breakdown
    
    ### Task 1: [Name]
    **File**: tasks/01-[name].md
    **Status**: pending
    **Estimate**: [hours]
    
    [Brief description]
    
    ### Task 2: [Name]
    **File**: tasks/02-[name].md
    **Status**: pending
    **Estimate**: [hours]
    
    [Continue for all tasks...]
    
    ## Progress Tracking
    - [ ] Task 1: [Name]
    - [ ] Task 2: [Name]
    [etc...]
    
    ## GitHub Sync Points
    - Planning complete: [Date/Time]
    - Last sync: Never
    - Next sync: After first task
    ```
    
    ## Technical Assessment
    
    Document in index.md:
    
    1. Data modeling:
       - Database schema changes
       - New Ecto schemas needed
       - Relationships between entities
    
    2. Business logic:
       - Ash actions required
       - Authorization policies
       - Validations and checks
    
    3. User interface:
       - LiveView components needed
       - Forms and interactions
       - Real-time updates
    
    4. Testing strategy:
       - Unit test scenarios
       - Integration test needs
       - Feature/behavior tests
    
    ## Task File Creation
    
    For each task, create `tasks/issue-{{ params.issue }}/tasks/0N-[name].md`:
    
    ```markdown
    # Task N: [Task Name]
    
    **Status**: pending
    **Created**: [Date/Time]
    **Started**: -
    **Completed**: -
    
    ## Purpose
    [What this task accomplishes for the feature]
    
    ## Scope
    
    ### Must Include
    - [Specific deliverables]
    - [Required functionality]
    
    ### Explicitly Excludes
    - [Items for other tasks]
    - [Out of scope items]
    
    ## Implementation Checklist
    - [ ] Write tests for [specific functionality]
    - [ ] Implement [specific component/feature]
    - [ ] Update [specific documentation]
    - [ ] Ensure quality gates pass
    
    ## Technical Details
    - [Specific implementation notes]
    - [Files likely to be modified]
    - [Patterns to follow]
    
    ## Acceptance Criteria
    - [Specific, measurable criteria]
    - [User-visible outcomes]
    
    ## Dependencies
    - Requires: [Previous task numbers if any]
    - Blocks: [Subsequent tasks if any]
    
    ## Session Notes
    [Will be populated during implementation]
    ```
    
    ## Session File Initialization
    
    Create `tasks/issue-{{ params.issue }}/session.md`:
    
    ```markdown
    # Implementation Session Notes
    
    **Issue**: #{{ params.issue }}
    **Started**: [Current Date/Time]
    
    ## Planning Phase - [Date/Time]
    
    ### Requirements Clarifications
    [Document any assumptions or clarifications made]
    
    ### Key Decisions
    - [Decision 1]: [Rationale]
    - [Decision 2]: [Rationale]
    
    ### Initial Learnings
    - [Any insights from planning]
    - [Patterns identified]
    
    ---
    [Implementation notes will be added here]
    ```
    
    ## Session Notes Update
    
    Add to session.md:
    ```markdown
    ### Planning Complete - [Time]
    - Created [N] tasks
    - Ready to start implementation
    ```
    
    ## Important Guidelines
    
    1. **Task Sizing**:
       - Aim for 2-4 hour tasks
       - If larger, break down further
       - Each task = one focused commit set
    
    2. **Clear Boundaries**:
       - No overlap between tasks
       - Explicit scope statements
       - Clear handoff points
    
    3. **Documentation**:
       - Session notes capture the journey
       - Task files track specific progress
       - Learnings accumulate throughout
    
    ## Return Message
    
    ```
    Created local task structure for issue #{{ params.issue }}:
    - Location: tasks/issue-{{ params.issue }}/
    - Tasks: [N] tasks created
    - Branch: feature/issue-{{ params.issue }}-[description]
    
    Ready to start implementation with:
    /build task=1
    ```
  </instructions>
</prompt>