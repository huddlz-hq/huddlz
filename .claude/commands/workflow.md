<prompt>
  <instructions>
    # Hybrid Development Workflow

    This document outlines the development process that combines GitHub Issues for tracking with local files for rich documentation.

    ## Complete Workflow

    Feature development follows five phases, maintaining both local context and GitHub visibility:

    ### 1. Plan Phase (Project Manager Mode)

    Analyze a GitHub issue and create local task structure:

    ```
    /plan issue=123
    ```

    This command:
    - Fetches requirements from GitHub issue
    - Deep-dives with structured questions
    - Creates local directory `tasks/issue-123/`
    - Generates task files with clear scope
    - Establishes feature branch
    - Posts planning summary to GitHub

    Creates:
    ```
    tasks/issue-123/
    ├── index.md       # Plan and progress tracking
    ├── session.md     # Implementation notes
    └── tasks/         # Individual task files
        ├── 01-setup.md
        ├── 02-models.md
        └── 03-ui.md
    ```

    ### 2. Build Phase (Expert Engineer Mode)

    Implement each task with TDD/BDD discipline:

    ```
    /build task=1
    ```

    This command:
    - Reads requirements from local task file
    - Updates task status to in_progress
    - Enforces test-first development
    - Documents progress in session.md
    - Captures course corrections with 🔄
    - Enforces quality gates
    - Requires user verification

    Quality Gates (Mandatory):
    - `mix format` - Clean formatting
    - `mix test` - 100% passing
    - `mix credo --strict` - Zero issues
    - `mix test test/features/` - All pass

    ### 3. Sync Phase (Communication Bridge)

    Keep GitHub updated with local progress:

    ```
    /sync
    ```

    This command:
    - Reads current status from local files
    - Generates concise progress summary
    - Posts update to GitHub issue
    - Maintains transparency without clutter

    Sync when:
    - Task completed
    - Major milestone reached
    - Course correction made
    - End of work session

    ### 4. Verify Phase (Senior Reviewer Mode)

    Comprehensive review of complete feature:

    ```
    /verify
    ```

    This command:
    - Checks all tasks are completed
    - Runs comprehensive quality checks
    - Tests integration and UX
    - Documents findings in session.md
    - Creates fix tasks if needed
    - Posts summary to GitHub

    ### 5. Reflect Phase (QA/Process Analyst Mode)

    Extract learnings from the journey:

    ```
    /reflect
    ```

    This command:
    - Analyzes session notes
    - Identifies patterns and insights
    - Creates local learnings.md
    - Updates global LEARNINGS.md
    - Generates PR description
    - Posts completion to GitHub

    ## File Structure Benefits

    ### Session Notes (session.md)
    Captures the implementation journey:
    - Real-time decision documentation
    - Course corrections with context
    - Technical discoveries
    - Progress timestamps

    ### Task Files (tasks/*.md)
    Maintain clear boundaries:
    - Specific scope and requirements
    - Implementation checklist
    - Status tracking
    - Dependencies

    ### Learning Accumulation
    Knowledge builds throughout:
    - Immediate capture in session.md
    - Task-specific insights
    - Feature-level learnings
    - Global patterns in LEARNINGS.md

    ## Workflow Benefits

    1. **Rich Context**: Session notes preserve the "why"
    2. **Fast Access**: No API calls for task details
    3. **Natural Flow**: File-based feels familiar
    4. **GitHub Integration**: Maintains visibility
    5. **Learning Capture**: Journey documented

    ## Best Practices

    1. **Continuous Documentation**: Update session.md as you work
    2. **Atomic Commits**: One per checklist item
    3. **Regular Syncs**: Keep GitHub informed
    4. **Quality First**: Never skip gates
    5. **Capture Everything**: Especially course corrections

    ## Command Reference

    ```bash
    # Start from GitHub issue
    /plan issue=123

    # Build tasks locally
    /build task=1
    /build task=2

    # Sync progress periodically
    /sync

    # Verify when complete
    /verify

    # Extract learnings
    /reflect

    # Create PR
    gh pr create --body-file tasks/issue-123/pr-description.md
    ```

    ## Migration from Pure GitHub

    If you have existing GitHub sub-issues:
    1. Use `/plan` to create local structure
    2. Copy requirements from sub-issues to task files
    3. Close sub-issues with reference to local tasks
    4. Continue with `/build task=N`

    ## Important Notes

    - Local files are source of truth during development
    - GitHub provides visibility and collaboration
    - Session notes capture the journey
    - Quality gates are never optional
    - Learning happens continuously

    This hybrid approach gives you the best of both worlds: rich local documentation with public progress tracking.
  </instructions>
</prompt>