<prompt>
  <params>
    notes_file # Path to the feature notes file containing the plan
    task # Optional specific task to focus on (if not provided, will use next task from notes)
  </params>

  <instructions>
    # Implementation Phase
    
    This command guides the actual development work, turning plans into working code.
    
    ## Preparation
    
    1. Read the notes file: {{ params.notes_file }}
    2. Review the Implementation Plan section
    3. Check the Current Status to understand progress
    4. Update the Session Log with a new entry:
       ```
       [{{ current_date }}] Starting implementation work on {{ params.task || "next planned task" }}...
       ```
    5. Update the Current Status section:
       ```
       - Phase: Implementation
       - Progress: X% (estimate based on completed work)
       - Current task: {{ params.task || "identified task" }}
       - Blockers: Any known issues
       ```
    
    ## Implementation Process
    
    6. Determine specific task to implement:
       - If {{ params.task }} is provided, focus on that specific task
       - Otherwise, identify the next logical task from the implementation plan
       
    7. For the identified task:
       - Create a new git branch if not already done
       - Research similar patterns in the codebase
       - Design the implementation approach
       - Develop the solution with test-driven development where appropriate
       - Test the implementation thoroughly
       - Refactor as needed to maintain code quality
       
    8. For each significant step completed:
       - Add a detailed entry to the Session Log
       - Update the Current Status section with latest progress
       - Document any challenges or insights in the Learnings section
    
    9. After completing a task:
       - Run all relevant tests
       - Format code according to project standards
       - Update the Implementation Plan to mark tasks as complete
       - Identify the next task to implement
    
    ## Quality Assurance
    
    10. Before considering a task complete:
        - Ensure code follows project standards (run `mix format`)
        - Verify all tests are passing
        - Check that the implementation matches the design plan
        - Review for edge cases and error handling
        - Validate against the original requirements
        - Document any deviations from the original plan and why they were necessary
    
    ## Important Rules
    
    - Always start by understanding the task in context of the overall plan
    - Follow test-driven development practices when appropriate
    - Keep the Session Log updated with detailed entries on progress
    - Document all key decisions and challenges encountered
    - Update the Current Status section frequently
    - Never commit directly to main branch
    - Maintain atomic, focused commits with clear messages
    - Follow established project patterns and coding standards
    - Run tests frequently during development
    
    ## Return Values
    
    Summarize the work completed, current progress percentage, and recommend next actions.
  </instructions>
</prompt>