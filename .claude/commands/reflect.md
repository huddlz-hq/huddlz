<prompt>
  <params>
    task_dir # Path or identifier for the task directory (full path, feature name, or timestamp)
  </params>

  <instructions>
    # Reflection Process
    
    This command analyzes completed work to extract learnings and improve future development.
    
    ## Task Directory Resolution
    
    1. Resolve the task directory from {{ params.task_dir }}:
       - If it's a full path (starting with "/"), use it directly
       - If it matches a timestamp pattern (e.g., "20250506120145"), find `notes/tasks/[timestamp]_*`
       - If it's a feature name (e.g., "create_groups"), find `notes/tasks/*_[feature_name]`
       - If not provided, use the most recent task directory in `notes/tasks/`
    
    2. If multiple matches or no matches found, ask the user to clarify
    
    ## Reflection Preparation
    
    3. Read the index.md file from the task directory
    4. Check if all tasks are marked as "completed"
       - If not all tasks are completed, inform the user and ask if they want to proceed anyway
    
    5. Create a new Reflection section in the index.md if it doesn't exist
    6. Add a reflection entry to the index.md:
       ```
       [{{ current_date }}] Starting reflection process...
       ```
    
    ## Holistic Analysis
    
    7. Review the entire task directory, including:
       - The index.md for overall progress and challenges
       - Each individual task file for specific learnings
       - The Verification section if it exists
    
    8. Analyze the entire development process, focusing on:
       - Task breakdown effectiveness (were tasks sized appropriately?)
       - Task sequencing (was the implementation order logical?)
       - Key decisions made and their outcomes
       - Challenges encountered and how they were addressed
       - Architectural or design patterns that worked well
       - Patterns that caused issues or needed reworking
       - Testing approaches and their effectiveness
       - Techniques that improved efficiency or quality
    
    ## Knowledge Extraction
    
    9. Add insights to the "Reflection" section of the index.md:
       - Organize learnings by categories (e.g., Design, Implementation, Testing, Process)
       - Use clear, actionable language
       - Include concrete examples
       - Focus on transferable knowledge
       - Include specific references to tasks where appropriate
    
    ## Global Knowledge Integration
    
    10. Update the central LEARNINGS.md file:
        - Open and read the LEARNINGS.md file
        - Identify categories where new learnings should be added
        - Add new insights in appropriate sections
        - Ensure there are no duplicates
        - Maintain consistent formatting
        - Reference the feature/task directory where relevant
    
    ## Process Improvement
    
    11. Based on the reflection, suggest improvements to:
        - Feature breakdown process
        - Task sizing and sequencing
        - Implementation approaches
        - Testing methodologies
        - Documentation practices
    
    12. Add a "Process Improvements" section to the index.md:
        ```
        ## Process Improvements
        - [Specific improvement 1]
        - [Specific improvement 2]
        ...
        ```
    
    ## Future Work
    
    13. Identify potential follow-up tasks or enhancements:
        - Extensions to the feature
        - Refactorings that could improve the implementation
        - Technical debt that should be addressed later
    
    14. Add a "Future Work" section to the index.md with these items
    
    ## Important Rules
    
    - Be specific and concrete in identifying learnings
    - Focus on actionable insights, not just observations
    - Consider both technical and process improvements
    - Look for patterns across multiple tasks
    - Separate one-off issues from systemic patterns
    - Keep the LEARNINGS.md file well-organized with clear categories
    - When adding to LEARNINGS.md, maintain a consistent style
    - Pay special attention to task breakdown effectiveness
    - ALWAYS update the LEARNINGS.md file with new insights
    
    ## Return Values
    
    Summarize the key learnings identified, improvements suggested, and changes made to LEARNINGS.md.
  </instructions>
</prompt>