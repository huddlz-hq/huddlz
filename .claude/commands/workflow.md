<prompt>
  <instructions>
    # Development Workflow
    
    This document outlines a streamlined development process optimized for solo development with AI assistance.
    
    ## Complete Workflow
    
    For a typical feature development, follow these phases in order:
    
    ### 1. Plan Phase
    
    Use the `/plan` command to analyze requirements and break them down into manageable tasks:
    
    ```
    /plan [description="brief feature description"]
    ```
    
    This command:
    - Creates a timestamped task directory
    - Analyzes requirements and breaks them into discrete tasks
    - Generates an index of all tasks in implementation order
    - Creates detailed specifications for each task
    - Returns the path to the task directory
    
    ### 2. Build Phase
    
    Use the `/build` command to implement each task in sequence:
    
    ```
    /build [task_dir="<task_directory_path>"]
    ```
    
    This command:
    - Automatically finds the next task to implement
    - Handles both starting new tasks and resuming in-progress work
    - Guides implementation based on the task specification
    - Updates progress in both the task file and index
    - Ensures quality through tests and formatting
    - Requires human verification before proceeding to the next task
    
    ### 3. Verify Phase
    
    Use the `/verify` command to review the complete feature:
    
    ```
    /verify [task_dir="<task_directory_path>"] [commit=true|false]
    ```
    
    This command:
    - Performs comprehensive review of the entire feature
    - Runs tests to verify correctness
    - Implements critical fixes
    - Documents verification results
    - Optionally commits changes
    
    ### 4. Reflect Phase
    
    Use the `/reflect` command to capture learnings:
    
    ```
    /reflect [task_dir="<task_directory_path>"]
    ```
    
    This command:
    - Analyzes the development process across all tasks
    - Documents learnings in both the task directory and LEARNINGS.md
    - Suggests process improvements
    - Identifies potential future work
    
    ## Task Organization
    
    Tasks are organized in timestamped directories with consistent naming:
    ```
    notes/tasks/[timestamp]_[description]/
      - index.md (overview and task sequence)
      - 0001_[task_name].md
      - 0002_[task_name].md
      - etc.
    ```
    
    Each task file contains:
    - Task description and boundaries
    - Implementation plan and checklist
    - Progress tracking
    - Quality assurance steps
    
    ## Task Progression
    
    Tasks are completed in sequence according to their numbering:
    1. Complete all items in the implementation checklist
    2. Ensure all tests are passing
    3. Format code according to project standards
    4. Commit changes following CLAUDE.md guidelines
    5. Get human verification
    6. Proceed to the next task
    
    ## Knowledge Management
    
    The central knowledge repository is maintained in:
    - `LEARNINGS.md` at the project root
    
    This file is automatically updated during the reflect phase to build a knowledge base over time.
    
    ## Directory Resolution
    
    All commands support flexible task directory resolution:
    - Full path: `/build /Users/name/project/notes/tasks/20250506_create_groups/`
    - Timestamp: `/build 20250506`
    - Feature name: `/build create_groups`
    
    If no task directory is specified, commands will use the most recent one.
    
    ## Important Note
    
    These commands are designed to work with:
    - Elixir/Phoenix architecture
    - Ash Framework data model
    - Feature requirements system
    - Cucumber and ExUnit testing patterns
    
    ### Command Usage Syntax
    
    When using these commands with Claude or other AI assistants, use the standard slash command format:
    
    ```
    /command param1="value1" param2="value2"
    ```
    
    For example:
    ```
    /plan description="Add user groups"
    /build task_dir="create_groups"
    ```
    
    The commands are loaded from the `.claude/commands/` directory and are project-specific. Claude recognizes them through this directory structure.
    
    When working with Claude or other AI assistants on this project, always refer to these custom commands to maintain consistency in development patterns and documentation.
  </instructions>
</prompt>