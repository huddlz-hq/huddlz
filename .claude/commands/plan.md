<prompt>
  <params>
    description # Optional brief feature description
  </params>

  <instructions>
    # Enhanced Task Decomposition Planning
    
    This command analyzes requirements, conducts thorough product management exploration, and breaks down features into manageable tasks.
    
    ## Initial Setup
    
    1. If description is not provided, ask the user for a brief feature description
    2. Generate a timestamp for the planning session
    3. Create the tasks directory structure:
       ```
       mkdir -p notes/tasks/[timestamp]_[description]/
       ```
    
    ## Feature Exploration
    
    1. Ask the user to describe the feature at a high level
    2. Conduct a structured product management interview with questions like:
       - What problem does this feature solve for users?
       - Who are the primary users of this feature?
       - How does this feature align with the overall product vision?
       - What specific actions should users be able to perform?
       - What are explicit constraints or limitations we should be aware of?
    
    ## Requirements Detailing
    
    1. Based on initial answers, drill down into specific areas:
       - Data requirements: "What information needs to be collected or displayed?"
       - User flows: "Walk me through the typical user journey for this feature"
       - Edge cases: "What should happen when [unexpected condition]?"
       - Access control: "Who should be able to perform these actions?"
       - Integration points: "How does this feature interact with existing functionality?"
    
    2. For each unclear aspect, ask follow-up questions until you have:
       - Clear scope boundaries (what is and isn't included)
       - Specific functional requirements
       - Non-functional requirements (performance, security)
       - Success criteria

    ## Technical Assessment
    
    1. Consider implementation details:
       - Data modeling: "What changes to data models are needed?"
       - API requirements: "What new endpoints or services are required?"
       - UI components: "What interface elements need to be created or modified?"
       - Authorization: "What permission checks are needed?"
    
    2. Identify potential technical challenges:
       - Complex logic or algorithms
       - Performance considerations
       - Migration considerations

    ## Feature Analysis
    
    1. Analyze the requirements to identify:
       - Core functionality needed
       - Data models and structures required
       - User interface components
       - API endpoints or services
       - Dependencies on existing systems
    2. Break down the feature into discrete, manageable tasks
    3. Determine the logical implementation sequence based on dependencies
    
    ## Task Documentation
    
    1. Create an index file: `notes/tasks/[timestamp]_[description]/index.md`
       ```markdown
       # Feature: [Feature Name]
       
       ## Overview
       [Comprehensive description of the overall feature based on discovery]
       
       ## User Stories
       - As a [user type], I want to [action], so that [benefit]
       - As a [user type], I want to [action], so that [benefit]
       ...
       
       ## Implementation Sequence
       1. [First task name] - [Brief description]
       2. [Second task name] - [Brief description]
       ...
       
       ## Success Criteria
       - [Specific, measurable criteria for feature completion]
       - [Observable user outcome that indicates success]
       ...
       
       ## Planning Session Info
       - Created: [Current date and time]
       - Feature Description: [Description]
       ```
    
    2. For each identified task, create a sequentially numbered file:
       ```
       notes/tasks/[timestamp]_[description]/0001_[task_name].md
       notes/tasks/[timestamp]_[description]/0002_[task_name].md
       ...
       ```
    
    3. Each task file should follow this template:
       ```markdown
       # Task: [Task Name]
       
       ## Context
       - Part of feature: [Feature Name]
       - Sequence: Task [X] of [Y]
       - Purpose: [Brief explanation of how this task fits in]
       
       ## Task Boundaries
       - In scope: [What should be done in this task]
       - Out of scope: [What should NOT be done in this task]
       
       ## Current Status
       - Progress: 0%
       - Blockers: [Any dependencies on other tasks]
       - Next steps: Begin implementation
       
       ## Requirements Analysis
       - [Specific requirements for this task]
       
       ## Implementation Plan
       - [Overall approach/strategy for this task]
       - [Design decisions]
       - [Technical considerations]
       
       ## Implementation Checklist
       1. [Specific action item #1] 
       2. [Specific action item #2]
       3. [Specific action item #3]
       ...
       
       ## Related Files
       - [Files that will likely need to be modified]
       
       ## Definition of Done
       - [Specific, measurable completion criteria]
       
       ## Quality Assurance
       
       ### AI Verification (Throughout Implementation)
       - Run appropriate tests after each checklist item
       - Run `mix format` before committing changes
       - Verify compilation with `mix compile` regularly
       
       ### Human Verification (Required Before Next Task)
       - After completing the entire implementation checklist, ask the user:
         "I've completed task [X]. Could you please verify the implementation by:
          1. Running the application (`mix phx.server`)
          2. Testing the new functionality
          If everything looks good, I'll proceed to the next task (Task [Y])."
       
       ## Progress Tracking
       - Update after completing each checklist item
       - Mark items as completed with timestamps
       - Document any issues encountered and how they were resolved
       
       ## Commit Instructions
       - Make atomic commits after completing logical units of work
       - Before finishing the task, ensure all changes are committed
       - Follow commit message standards in CLAUDE.md
       - Update the Session Log with commit details
       
       ## Session Log
       - [Current date and time] Started task planning...
       
       ## Next Task
       - Next task: [0002_next_task_name]
       - Only proceed to the next task after:
         - All checklist items are complete
         - All tests are passing
         - Code is properly formatted
         - Changes have been committed
         - User has verified and approved the implementation
       ```
    
    ## Important Guidelines
    
    1. Task Sizing:
       - Each task should be completable in a single focused work session
       - Tasks should have clear, measurable completion criteria
       - If a task seems too large, break it down further
    
    2. Dependency Management:
       - Order tasks to minimize dependencies between them
       - Clearly document any dependencies in the Context section
       - Ensure the implementation sequence is technically feasible
    
    3. Task Clarity:
       - Each task should have a clear, specific purpose
       - Task boundaries should be explicit
       - Implementation checklists should be actionable and concrete
    
    ## Return Values
    
    Return the path to the tasks directory and a summary of the tasks created.
  </instructions>
</prompt>