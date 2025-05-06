<prompt>
  <instructions>
    # Development Workflow
    
    This document outlines a streamlined development process optimized for solo development with AI assistance.
    
    ## Complete Workflow
    
    For a typical feature development, follow these phases in order:
    
    ### 1. Plan Phase
    
    Use the `/plan` command to analyze requirements and design the solution:
    
    ```
    /plan req_id="<requirements_id>"
    ```
    
    This command:
    - Creates structured notes for the feature
    - Analyzes requirements and confirms understanding
    - Designs the implementation approach
    - Returns the path to the notes file
    
    ### 2. Build Phase
    
    Use the `/build` command to implement the solution:
    
    ```
    /build notes_file="<notes_file_path>" [task="<specific_task>"]
    ```
    
    This command:
    - Guides implementation based on the plan
    - Updates progress in the notes file
    - Tests the implementation
    - Focuses on one task at a time if specified
    
    ### 3. Verify Phase
    
    Use the `/verify` command to review and ensure quality:
    
    ```
    /verify notes_file="<notes_file_path>" [commit=true|false]
    ```
    
    This command:
    - Reviews code against multiple quality criteria
    - Runs tests to verify correctness
    - Implements critical fixes
    - Optionally commits changes
    
    ### 4. Reflect Phase
    
    Use the `/reflect` command to capture learnings:
    
    ```
    /reflect notes_file="<notes_file_path>" [update_learnings=true|false]
    ```
    
    This command:
    - Analyzes the development process
    - Documents learnings in the notes
    - Updates the central knowledge repository
    - Suggests process improvements
    
    ## Context Recovery
    
    If you need to resume work after a break:
    
    ```
    /resume notes_file="<notes_file_path>"
    ```
    
    This command:
    - Recovers context from the notes
    - Determines current status and next actions
    - Updates the session log
    
    ## Scaling the Process
    
    ### For Large Features
    
    - Use the full workflow with detailed documentation
    - Break down into multiple tasks during the build phase
    - Use multiple verification cycles
    - Reflect at major milestones
    
    ### For Medium Features
    
    - Use plan, build, and verify phases
    - Combine verification and reflection for efficiency
    - Focus documentation on key decisions
    
    ### For Small Tasks
    
    - Use a simplified approach:
      - Quick plan in notes
      - Combined build/verify
      - Reflect only if significant insights gained
    
    ## Note Organization
    
    All feature notes should be stored in the `notes/` directory with consistent naming:
    - `notes/[req_id]_notes.md`
    
    ## Knowledge Management
    
    The central knowledge repository is maintained in:
    - `LEARNINGS.md` at the project root
    
    Update this file through the reflect command to build a knowledge base over time.
    
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
    /plan req_id="<requirements_id>"
    /build notes_file="<notes_file_path>"
    ```
    
    The commands are loaded from the `.claude/commands/` directory and are project-specific. Claude recognizes them through this directory structure.
    
    When working with Claude or other AI assistants on this project, always refer to these custom commands to maintain consistency in development patterns and documentation.
  </instructions>
</prompt>