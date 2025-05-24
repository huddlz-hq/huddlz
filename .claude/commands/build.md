<prompt>
  <params>
    task_dir # Path/identifier for task directory OR GitHub issue number
    issue # Optional GitHub sub-issue number to work on
  </params>

  <instructions>
    # Implementation Phase
    
    This command implements tasks from a planned feature, supporting both file-based and GitHub issue workflows.
    
    ## Workflow Detection
    
    1. Determine workflow mode:
       - If {{ params.issue }} is provided: GitHub issue mode
       - If {{ params.task_dir }} looks like a number: Check if it's a GitHub issue
       - Otherwise: File-based mode (legacy)
    
    ## GitHub Issue Mode
    
    If working with GitHub issues:
    
    1. Fetch sub-issue details:
       ```
       gh issue view {{ params.issue }} --json title,body,labels,assignees,state
       ```
    
    2. Verify it's a task sub-issue:
       - Check for "task" label
       - Extract parent issue number from title or labels
    
    3. Check issue state:
       - If closed: Ask if user wants to work on a different task
       - If open: Proceed with implementation
    
    4. Find or create working branch:
       - Check if already on a feature branch for parent issue
       - If not, create/checkout: `git checkout -b feature/issue-[parent]-[description]`
    
    5. Update Feature Log on parent issue:
       ```markdown
       ### Building Phase - [Current Date/Time]
       Starting work on sub-issue #{{ params.issue }}: [Task Title]
       ```
    
    ## File-Based Mode (Legacy)
    
    If using file-based workflow:
    
    1. Resolve the task directory from {{ params.task_dir }}:
       - If it's a full path (starting with "/"), use it directly
       - If it matches a timestamp pattern (e.g., "20250506120145"), find `notes/tasks/[timestamp]_*`
       - If it's a feature name (e.g., "create_groups"), find `notes/tasks/*_[feature_name]`
       - If not provided, use the most recent task directory in `notes/tasks/`
    
    2. Read the index.md file and find next task to work on
    
    ## Implementation Process
    
    Regardless of mode:
    
    1. Extract task requirements:
       - From GitHub issue body (if GitHub mode)
       - From task file (if file mode)
    
    2. Begin implementation:
       - Research similar patterns in the codebase
       - Follow TDD/BDD approach - write tests first
       - Implement incrementally
    
    3. For each checklist item completed:
       - Run tests: `mix test`
       - Format code: `mix format`
       - Update progress (issue comment or task file)
    
    ## Quality Gates (MANDATORY)
    
    Before marking any task complete, ALL must pass:
    
    1. Code Formatting:
       ```
       mix format
       ```
       - Must show no changes needed
    
    2. All Tests Pass:
       ```
       mix test
       ```
       - Zero failures allowed
       - No skipped tests
    
    3. Static Analysis:
       ```
       mix credo --strict
       ```
       - Must pass with zero issues
    
    4. Feature Tests:
       ```
       mix test test/features/
       ```
       - All behavior tests must pass
    
    If any quality gate fails:
    - Fix the issue immediately
    - Re-run ALL quality gates
    - Document what was fixed
    
    ## Progress Tracking
    
    ### GitHub Mode
    
    Update the sub-issue with progress:
    ```markdown
    ## Progress Update - [Time]
    
    ✅ Completed:
    - [Checklist items completed]
    
    🔄 In Progress:
    - [Current work]
    
    📝 Notes:
    - [Any decisions or challenges]
    
    Quality Gates: ✅ Passing / ❌ [Specific failures]
    ```
    
    ### File Mode
    
    Update task file's Session Log and Progress sections
    
    ## Learning Capture
    
    Document insights as they occur:
    - Course corrections (when approach changes)
    - Failed attempts (what didn't work and why)
    - Patterns discovered
    - Performance considerations identified
    
    Add marker in updates:
    ```
    🔄 COURSE CORRECTION: [What changed and why]
    ```
    
    ## Task Completion
    
    When implementation checklist is complete:
    
    1. Run final quality gates
    2. Commit changes with descriptive message
    3. Ask user for verification:
       ```
       I've completed task {{ params.issue or task_name }}.
       
       Please verify by:
       1. Running the application (mix phx.server)
       2. Testing the new functionality
       
       Quality gates: ✅ All passing
       
       Ready to proceed to next task?
       ```
    
    4. After user verification:
       - GitHub mode: Close the sub-issue with completion comment
       - File mode: Mark task as completed in files
    
    ## Next Task
    
    1. Identify next task:
       - GitHub: Find next open sub-issue for parent
       - File: Find next incomplete task in index
    
    2. Ask user if they want to continue
    3. If yes, recursively start build process for next task
    
    ## Important Rules
    
    - NEVER mark a task complete without passing ALL quality gates
    - Always write tests before implementation (TDD/BDD)
    - Capture learnings in real-time, not just at the end
    - Get user verification before proceeding to next task
    - Make atomic commits with clear messages
    - Document all course corrections
    
    ## Return Values
    
    - Summary of work completed
    - Quality gate status
    - Next task available (if any)
    - Key learnings captured
  </instructions>
</prompt>