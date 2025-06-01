<prompt>
  <params>
    issue # GitHub issue number to work on
    task # Optional: Task number (defaults to next pending task)
  </params>

  <instructions>
    # Implementation Phase

    This command implements a specific task from the local task files with TDD/BDD discipline.

    ## Parameter Handling

    1. **Issue is required**:
       - Must have {{ params.issue }} parameter
       - If missing, error with: "Please specify issue: /build issue=123"

    2. **Task is optional**:
       - If {{ params.task }} provided, use it
       - If not provided, find next pending task:
         - Read `tasks/issue-{{ params.issue }}/index.md`
         - Find first unchecked task in Progress Tracking section
         - If none found, report "All tasks complete!"

    ## Task Location

    1. Verify issue directory exists:
       ```
       tasks/issue-{{ params.issue }}/
       ```
       If not found: "No task structure found for issue {{ params.issue }}. Run /plan issue={{ params.issue }} first."

    2. Locate task file:
       - If task number provided: `tasks/issue-{{ params.issue }}/tasks/0{{ params.task }}-*.md`
       - If auto-detected: Use task number from index.md

    3. Validate task:
       - Read task file
       - Check status field
       - If completed and task was specified: "Task {{ params.task }} is already completed"
       - If completed and auto-detected: Find next pending task

    ## Session Initialization

    1. Update task file status:
       - Change `**Status**: pending` to `**Status**: in_progress`
       - Set `**Started**: [Current Date/Time]`

    2. Append to session file `tasks/issue-[issue]/session.md`:
       ```markdown

       ## Task {{ params.task }} Implementation - [Date/Time]

       ### Starting State
       - Task: [Task name from file]
       - Approach: [Initial implementation plan]
       ```

    ## Implementation Process

    1. Read task requirements:
       - Implementation checklist
       - Acceptance criteria
       - Technical details
       - Dependencies

    2. Begin TDD/BDD implementation:
       - Research similar patterns in codebase
       - Write tests FIRST for each checklist item
       - Implement incrementally
       - Run quality gates after each change

    3. For each checklist item:
       - Write failing test
       - Implement minimal code to pass
       - Refactor if needed
       - Update task file checklist
       - Document progress in session notes

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
    - Document issue and fix in session notes

    ## Progress Documentation

    Continuously update session file during implementation:

    ```markdown
    ### Progress Log

    **[Time]** - Working on: [Current checklist item]
    - Wrote test: [test file:line]
    - Test failing as expected ✓

    **[Time]** - Implementation
    - Added [what was added]
    - Test now passing ✓

    **[Time]** - Quality Gates
    - All tests passing: ✓
    - Format clean: ✓
    - Credo clean: ✓
    ```

    ## Learning Capture

    Document insights immediately in session file:

    1. **Course Corrections**:
       ```markdown
       🔄 COURSE CORRECTION - [Time]
       - Tried: [What was attempted]
       - Issue: [Why it didn't work]
       - Solution: [What worked instead]
       - Learning: [Generalizable principle]
       ```

    2. **Discoveries**:
       - Useful patterns found
       - Performance considerations
       - Testing strategies that worked well

    3. **Challenges**:
       - Framework quirks
       - Integration complexities
       - Workarounds needed

    ## Commit Strategy

    Make atomic commits after each checklist item:
    ```
    git add [relevant files]
    git commit -m "feat(issue-{{ issue }}): [specific change]"
    ```

    Follow conventional commits:
    - `feat:` for new functionality
    - `test:` for test additions
    - `fix:` for bug fixes
    - `refactor:` for code improvements

    ## Task Completion

    When all checklist items complete:

    1. Run final quality gates
    2. Update task file:
       - Change `**Status**: in_progress` to `**Status**: completed`
       - Set `**Completed**: [Current Date/Time]`
       - Check all checklist items

    3. Update index file:
       - Check off task in Progress Tracking section
       - Update any relevant technical notes

    4. Final session notes:
       ```markdown
       ### Task Complete - [Time]

       **Summary**: Successfully implemented [task name]

       **Key Changes**:
       - [Major change 1]
       - [Major change 2]

       **Tests Added**: [count]
       **Files Modified**: [count]

       **Quality Gates**: ✅ All passing
       ```

    5. Ask user for verification:
       ```
       Task {{ params.task }} complete!

       Please test the implementation:
       1. Run `mix phx.server`
       2. [Specific testing instructions based on task]

       Quality gates are all passing.
       Ready to continue with the next task?
       ```

    ## Next Task

    1. Find next pending task in directory:
       - List all task files in `tasks/issue-{{ params.issue }}/tasks/`
       - Find first with `**Status**: pending`

    2. If found, suggest:
       ```
       Next task available: Task [N] - [Name]
       Continue with: /build issue={{ params.issue }} task=[N]
       Or simply: /build issue={{ params.issue }}
       ```

    3. If none found:
       ```
       All tasks complete! Ready for verification phase.
       Use: /verify issue={{ params.issue }}
       ```

    ## GitHub Sync Points

    At task completion, optionally sync to GitHub:
    ```markdown
    ## 🚀 Progress Update

    Completed Task {{ params.task }}: [Task Name]

    **Changes**:
    - [Key implementation points]

    **Next**: Working on Task [N]
    ```

    ## Important Rules

    - NEVER skip quality gates
    - ALWAYS write tests first (TDD/BDD)
    - Document learning in real-time
    - Keep session notes detailed
    - Make atomic, well-described commits
    - Update task status immediately
    - Get user verification before proceeding

    ## Return Values

    - Task completed: #{{ params.task }}
    - Quality gates: [Status]
    - Commits made: [List]
    - Session notes: Updated
    - Next task: [Number] or None
  </instructions>
</prompt>