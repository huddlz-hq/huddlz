<prompt>
  <params>
    issue # GitHub sub-issue number to work on
  </params>

  <instructions>
    # Implementation Phase
    
    This command implements a specific task from a GitHub sub-issue with TDD/BDD discipline.
    
    ## Issue Validation
    
    1. Fetch sub-issue details:
       ```
       gh issue view {{ params.issue }} --json title,body,labels,assignees,state,comments
       ```
    
    2. Validate it's a task sub-issue:
       - Check for "task" label
       - Extract parent issue number from title or labels
       - Verify issue is open
       - If closed, suggest next open sub-issue
    
    3. Ensure on correct branch:
       - Check current branch matches parent issue pattern
       - If not, checkout or create: `git checkout -b feature/issue-[parent]-[description]`
    
    ## Progress Initialization
    
    1. Check for existing progress in issue comments
       - Look for "Progress Update" comments
       - Determine what's already completed
       - Identify current state
    
    2. Update parent issue Feature Log:
       ```markdown
       ### Building Phase - [Current Date/Time]
       Starting work on sub-issue #{{ params.issue }}: [Task Title]
       ```
    
    3. Add initial progress comment if starting fresh:
       ```markdown
       ## Progress Update - [Time]
       
       Starting implementation of this task.
       
       ✅ Completed:
       - None yet
       
       🔄 In Progress:
       - Setting up implementation
       
       📝 Approach:
       - [Initial implementation strategy]
       ```
    
    ## Implementation Process
    
    1. Extract requirements from issue body:
       - Implementation checklist items
       - Acceptance criteria
       - Technical details
       - Dependencies
    
    2. Begin TDD/BDD implementation:
       - Research similar patterns in codebase
       - Write tests FIRST for each checklist item
       - Implement incrementally
       - Run tests after each change
    
    3. For each checklist item:
       - Write failing test
       - Implement minimal code to pass
       - Refactor if needed
       - Update progress comment
    
    ## Quality Gates (MANDATORY)
    
    After each significant change, run ALL:
    
    ```bash
    mix format              # Must be clean
    mix test               # Must be 100% passing
    mix credo --strict     # Must have zero issues
    mix test test/features/ # All scenarios must pass
    ```
    
    If ANY gate fails:
    - Fix immediately
    - Re-run ALL gates
    - Document what was fixed
    
    ## Progress Tracking
    
    Update issue comment regularly:
    ```markdown
    ## Progress Update - [Time]
    
    ✅ Completed:
    - [x] Wrote tests for [functionality]
    - [x] Implemented [component]
    
    🔄 In Progress:
    - Working on [current item]
    
    📝 Notes:
    - [Key decisions made]
    - [Challenges encountered]
    
    Quality Gates: ✅ All passing
    ```
    
    ## Learning Capture
    
    Document insights immediately:
    
    1. **Course Corrections** (when approach changes):
       ```markdown
       🔄 COURSE CORRECTION:
       - Original: [What was tried]
       - Issue: [Why it didn't work]
       - New approach: [What worked]
       - Learning: [General principle]
       ```
    
    2. **Pattern Discoveries**:
       - Useful patterns found
       - Performance optimizations
       - Testing strategies
    
    3. **Challenges**:
       - Unexpected complexity
       - Framework limitations
       - Integration issues
    
    ## Commit Strategy
    
    Make atomic commits:
    - After each checklist item
    - With descriptive messages
    - Following conventional commits:
      ```
      feat: add user authentication to groups
      test: add coverage for group permissions
      fix: resolve N+1 query in member list
      ```
    
    ## Task Completion
    
    When all checklist items done:
    
    1. Run final quality gates
    2. Ensure all tests pass
    3. Review implementation against acceptance criteria
    4. Add completion comment:
       ```markdown
       ## Task Complete! ✅
       
       All implementation checklist items completed.
       
       **Quality Gates:** All passing
       - Tests: [X] passed, 0 failed
       - Format: Clean
       - Credo: No issues
       
       **Ready for verification.**
       
       Please review by:
       1. Running `mix phx.server`
       2. Testing the functionality
       3. Confirming acceptance criteria are met
       ```
    
    5. Ask user for verification:
       ```
       I've completed task #{{ params.issue }}.
       
       Please verify the implementation works as expected.
       Quality gates are all passing.
       
       Ready to proceed to the next task?
       ```
    
    6. After user confirmation:
       - Close the sub-issue with final comment
       - Update parent issue task list (check the box)
    
    ## Next Task
    
    1. Find next open sub-issue for parent:
       ```
       gh issue list --label "parent-[number]" --state open --json number,title
       ```
    
    2. If found, ask user:
       ```
       Next task available: #[number] - [title]
       Would you like to continue with `/build issue=[number]`?
       ```
    
    ## Important Rules
    
    - NEVER skip quality gates
    - ALWAYS write tests first (TDD/BDD)
    - Capture learnings in real-time
    - Make atomic, focused commits
    - Get user verification before closing
    - Document all course corrections
    - Keep issue comments up to date
    
    ## Return Values
    
    - Task completed: #{{ params.issue }}
    - Quality gates: [Status]
    - Commits made: [Count]
    - Next task: #[number] or None
    - Key learnings: [Summary]
  </instructions>
</prompt>