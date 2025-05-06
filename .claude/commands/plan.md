<prompt>
  <params>
    feature_id # Either the full requirements filename (e.g., "0001_list_events.md") or just the feature number (e.g., "0001")
  </params>

  <instructions>
    # Combined Planning Phase
    
    This command handles both analysis and design in a streamlined process.
    
    ## Initial Setup
    
    1. Create the `notes` directory if it doesn't exist: `mkdir -p notes`
    2. Extract information from the feature ID:
       - If {{ params.feature_id }} contains a file extension (e.g., "0001_list_events.md"), use this filename
       - If {{ params.feature_id }} is just a number (e.g., "0001"), find the matching file in docs/requirements/
    3. Use the feature ID as prefix for your notes file: `notes/[FEATURE_ID]_notes.md`
       - Example: `notes/0001_notes.md`
    
    ## Note Structure
    
    Create a new notes file with this structure:
    
    ```markdown
    # Feature: [Feature Name] (Feature-{{ params.feature_id }})
    
    ## Current Status
    - Phase: Planning
    - Progress: 0%
    - Blockers: None
    - Next steps: Complete planning and analysis
    
    ## Requirements Analysis
    [Requirements will be filled in during analysis]
    
    ## Implementation Plan
    [Design decisions will be documented here]
    
    ## UI Component Selection
    - Primary components from DaisyUI: [component names]
    - Layout approach: [grid/flex/etc.]
    - Responsive considerations: [breakpoints]
    - Theme customization: [any theme tweaks]
    - References to DaisyUI documentation: [links]
    
    ## Session Log
    [{{ current_date }}] Started planning phase...
    
    ## Learnings
    [This section will capture insights during development]
    ```
    
    ## Analysis Phase
    
    1. Read and analyze the PRD file thoroughly
    2. Update the Requirements Analysis section with:
       - Clear list of explicit requirements from the PRD
       - Any implicit requirements you've identified
       - Areas requiring clarification
       - Your assumptions
    3. Ask the user to confirm your understanding
    4. Update the notes based on user feedback
    
    ## Design Phase
    
    After user confirmation:
    
    1. Propose a high-level implementation plan
    2. Discuss design alternatives and tradeoffs
    3. Check for existing patterns in the codebase
    4. Select appropriate UI components from DaisyUI:
       - Review requirements for UI elements needed
       - Identify matching DaisyUI components from documentation
       - Consider responsive behavior and theming
       - Document component choices with documentation links
    5. Update the Implementation Plan section with:
       - Chosen approach with rationale
       - Architecture and data flow diagrams (using MermaidJS)
       - Technical components needed
       - Testing strategy
    6. Update the UI Component Selection section with:
       - Specific DaisyUI components to use (buttons, cards, etc.)
       - Layout structure (grid, flex, container choices)
       - Responsive design approach
       - Any theme customizations needed
       - Links to relevant DaisyUI documentation
    7. Get user approval before implementation
    
    ## Important Rules
    
    - Do not write implementation code during planning
    - Document all key decisions and rationales
    - Always use consistent formatting in notes
    - Break down complex problems into manageable components
    - Update the Session Log with timestamped entries
    - Focus on understanding the problem completely before designing
    - Examine existing codebase patterns before proposing new ones
    
    ## Return Values
    
    Return the path to the created notes file for reference in future commands.
  </instructions>
</prompt>