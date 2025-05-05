<prompt>
  <params>
    prd_id # Either the full PRD filename (e.g., "0001_list_events.md") or just the PRD number (e.g., "0001")
  </params>

  <system>
    When executing a task, NEVER begin writing code immediately. Always start with analysis and planning.
    Verify understanding of the task with the user BEFORE proposing implementation details.
    Always create a new git branch for each task to avoid conflicts with main
  </system>

  <instructions>
    # Task Execution Process
    Follow these steps in STRICT ORDER:
    
    ## Setup
    
    BEFORE beginning: create a new markdown file to capture your notes while you work on this issue.
    
    1. Create the `notes` directory if it doesn't exist: `mkdir -p notes`
    2. Extract information from the PRD ID:
       - If {{ params.prd_id }} contains a file extension (e.g., "0001_list_events.md"), use this filename
       - If {{ params.prd_id }} is just a number (e.g., "0001"), find the matching file in docs/requirements/
       - If multiple files match, use the first one and notify the user
    3. Use the PRD number as prefix for your notes file: `notes/[PRD_NUMBER]_notes.md`
       - For example: `notes/0001_notes.md`
    4. Record the current PRD version information:
       - Add a "PRD Tracking" section at the top of your notes
       - Include the PRD file path (e.g., "docs/requirements/0001_list_events.md")
       - Record the PRD file's last modification date
       - If the PRD contains version information, record it
       - This will help track if requirements change during development
    5. Structure your notes file with clear headings for each phase of development

    ## Phase 1: Task Analysis
    1. Determine the full PRD path:
       - If {{ params.prd_id }} contains a file extension, use it directly: `docs/requirements/{{ params.prd_id }}`
       - If {{ params.prd_id }} is just a number (e.g., "0001"), find the matching file: `docs/requirements/{{ params.prd_id }}*.md`
    2. Read and analyze the PRD file
    3. Summarize the task requirements and constraints in your own words
    4. Create a "Requirements Analysis" section in your notes with:
       - Clear list of explicit requirements from the PRD
       - Any implicit requirements you've identified
       - Areas of ambiguity or uncertainty that need clarification
       - Assumptions you're making based on the PRD
    5. Explicitly ask the user to confirm your understanding before proceeding
    6. Document any ambiguities or points requiring clarification in your notes
    7. Once the user has confirmed your understanding or provided clarifications:
       - Update your notes with the clarified requirements
       - Mark any assumptions as either confirmed or corrected
       - Create a final, clear list of requirements in your notes file
    
    ## Phase 2: Solution Design
    1. Only after user confirms your understanding, propose a high-level implementation plan
    2. Discuss design alternatives and tradeoffs
    3. Ask for feedback on your proposed approach
    4. Work with the user to refine the implementation plan
    5. Analyze existing patterns in the codebase to ensure consistency
    6. Check for existing testing practices and documentation standards
    7. Add a new section to your notes document describing the solution we've agreed upon. Include any helpful diagrams in MermaidJS format.
    8. Explicitly request approval before proceeding to implementation

    ## Phase 3: Implementation
    1. ONLY after explicit approval, begin implementing the solution
    2. Create a new git branch for your work with a descriptive name following this convention:
       - Use the format: `feature/[PRD_NAME]` for new features
       - Use the format: `fix/[PRD_NAME]` for bug fixes
       - Where [PRD_NAME] is the full PRD filename without the extension
       - For example, if the PRD is "0001_list_events.md", use "feature/0001_list_events"
    3. Work through the checklist methodically, updating it as you complete items
    4. For complex changes, show staged implementations and request feedback
    5. Handle edge cases and add error resilience
    6. Ensure namespaces and imports follow project conventions
    7. For frontend changes, verify component integration with parent components
    8. Write automated tests for your implementation:
       - Follow the project's testing guidelines in docs/testing.md
       - Write Cucumber feature tests for user-facing functionality
       - Include unit tests for critical business logic
       - Use the appropriate test commands from CLAUDE.md
       - Verify all tests pass before considering the implementation complete
    9. Test key functionality before marking items as complete
    10. Update the note file with any pertinent information (eg. key decisions, new information, etc.)
    11. Prepare a detailed commit message describing the changes

    ## Phase 4: Review
    1. Review the implementation critically using these code review criteria:
       - Correctness: Does the code correctly implement the requirements?
       - Completeness: Are all requirements addressed?
       - Security: Are there any security vulnerabilities?
       - Performance: Are there any potential performance issues?
       - Readability: Is the code easy to understand?
       - Maintainability: Will the code be easy to maintain?
       - Testing: Are tests comprehensive and do they cover edge cases?
       - Project Standards: Does the code follow the project's style guidelines?
    2. Note areas that may need additional documentation or inline comments
    3. Highlight potential future maintenance challenges
    4. Suggest improvements for robustness, performance, or readability
    5. Incorporate your own suggestions if you deem them valuable
    6. Run static analysis tools if available in the project
    7. Ensure all tests still pass after your review changes
    8. Update the note file with anything you learned from the review or change you've made

    ## Phase 5: Submit
    1. Commit your changes in a new branch
    2. Include a detailed description in your commit message
    3. Add a summary of your changes in the notes file

    ## Phase 6: Iterate
    1. Once you have received feedback from the user, incorporate all of the suggested changes
    2. Create additional commits with clear commit messages explaining the changes made
    3. Update your notes file with information about the changes and how they addressed the feedback
    4. Repeat this process for each round of feedback until the user is satisfied with the implementation

    ## Phase 7: Reflect
    1. Reflect on anything you have learned during this process, eg.
      - design discussions with the user
      - feedback received on your implementation
      - issues found during testing
    2. Based on this reflection, propose changes to relevant documents and prompts to ensure those learnings are incorporated into future sessions. Consider artifacts such as:
      - README.md at the project root
      - folder-level README files
      - file-level documentation comments
      - base prompt (ie. CLAUDE.md)
      - this custom command prompt (ie. .claude/commands/bake.md)
    3. Create a separate branch for any documentation improvements
    4. Update your notes with anything you've learned.

    # Important Rules
    - NEVER write any implementation code during Phase 1 or 2
    - ALWAYS get explicit approval before moving to each subsequent phase
    - ALWAYS follow the project's coding standards and guidelines in CLAUDE.md
    - Run `mix format` before committing any changes to ensure proper formatting
    - Break down problems into manageable components
    - Consider edge cases and error handling in your design
    - Use research tools to understand the codebase before proposing changes
    - Examine similar functionality in the codebase to follow established patterns
    - Pay special attention to namespace resolution and import patterns
    - When in doubt, clarify with the user rather than making assumptions
    - Include clear acceptance criteria in your implementation plan
    - For full-stack features, test both frontend and backend components together
    - Never commit code directly to the `main` branch
    - Add to your working note whenever you discover new information
    - Whenever you learn something new, ensure that your note file is updated to reflect what you've learned
    - When taking notes include permalinks to both internal and external resources whenever possible
    - Always use MermaidJS when documenting designs or diagramming
    - Keep your note file well organized with proper headings and a sensible information hierarchy
    - Your note file MUST be formatted in markdown
  </instructions>
</prompt>
