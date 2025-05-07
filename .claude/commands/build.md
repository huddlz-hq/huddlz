<prompt>
  <params>
    task_dir # Path or identifier for the task directory (full path, feature name, or timestamp)
  </params>

  <instructions>
    # Implementation Phase
    
    This command implements tasks from a planned feature, supporting both starting new tasks and resuming in-progress work.
    
    ## Task Directory Resolution
    
    1. Resolve the task directory from {{ params.task_dir }}:
       - If it's a full path (starting with "/"), use it directly
       - If it matches a timestamp pattern (e.g., "20250506120145"), find `notes/tasks/[timestamp]_*`
       - If it's a feature name (e.g., "create_groups"), find `notes/tasks/*_[feature_name]`
       - If not provided, use the most recent task directory in `notes/tasks/`
    
    2. If multiple matches or no matches found, ask the user to clarify
    
    ## Task Identification
    
    3. Read the index.md file from the task directory
    4. Determine which task to work on by:
       - Finding the first task marked as "in progress" in the index
       - If no task is in progress, finding the first task not marked as "completed"
       - If all tasks are complete, inform the user and exit
    
    5. Load the corresponding task file (e.g., "0001_create_data_model.md")
    
    ## Progress Assessment
    
    6. Determine if this is a new task or resuming work:
       - Check "Current Status" section for progress percentage
       - Review "Progress Tracking" section for completed items
       - Examine "Session Log" for the most recent activity
    
    7. If resuming work:
       - Update the Session Log with a new entry:
         ```
         [{{ current_date }}] Resuming implementation work...
         ```
       - Provide a summary of what's been done and what remains
    
    8. If starting a new task:
       - Update the Session Log with a new entry:
         ```
         [{{ current_date }}] Starting implementation of this task...
         ```
       - Update the Current Status section:
         ```
         - Progress: 0%
         - Blockers: None
         - Current activity: Starting implementation
         ```
       - Update the index.md to mark this task as "in progress"
    
    ## Implementation Process
    
    9. For the identified task:
       - Research similar patterns in the codebase
       - Implement the solution following the task's Implementation Plan
       - Work through each item in the Implementation Checklist
    
    10. After completing each checklist item:
        - Run appropriate tests
        - Format code according to project standards
        - Add a detailed entry to the Session Log
        - Update the Progress Tracking section
        - Update the Current Status with new progress percentage
    
    11. Update the index.md regularly to reflect overall feature progress
    
    ## Quality Assurance
    
    12. Before considering a task complete:
        - Ensure all checklist items are completed
        - Run all tests with `mix test`
        - Format code with `mix format`
        - Verify the implementation meets the Definition of Done criteria
        - Commit all changes following CLAUDE.md guidelines
    
    13. Ask the user to verify the implementation:
        - Prompt them to run the application and test the functionality
        - Wait for confirmation before proceeding
    
    14. After user verification:
        - Mark the task as completed in its file:
          ```
          - Progress: 100%
          - Current activity: Completed
          ```
        - Update the index.md to mark the task as "completed"
        - Provide a summary of the work done
    
    ## Task Transition
    
    15. Identify the next task from the index.md
    16. If there is a next task, ask the user if they want to continue to that task
    17. If the user wants to continue, recursively start the process for the next task
    
    ## Important Rules
    
    - Always work through tasks in the sequence defined in the index
    - Keep both the task file and index.md updated with progress
    - Follow test-driven development practices when appropriate
    - Document all key decisions and challenges encountered
    - Maintain atomic, focused commits with clear messages
    - Follow established project patterns and coding standards
    - Run tests frequently during development
    - Always get user verification before marking a task as complete
    
    ## Return Values
    
    Summarize the work completed, overall feature progress, and next task (if any).
  </instructions>
</prompt>