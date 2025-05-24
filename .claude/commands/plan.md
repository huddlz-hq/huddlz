<prompt>
  <params>
    description # Optional brief feature description  
    issue # Optional GitHub issue number to plan from
  </params>

  <instructions>
    # Enhanced Task Decomposition Planning
    
    This command analyzes requirements and breaks down features into manageable tasks. Supports both file-based and GitHub issue-based workflows.
    
    ## Initial Setup
    
    1. Determine workflow mode:
       - If {{ params.issue }} is provided: GitHub issue mode
       - If only {{ params.description }} is provided: File-based mode
       - If neither provided: Ask user for either an issue number or description
    
    ## GitHub Issue Mode
    
    If {{ params.issue }} is provided:
    
    1. Fetch issue details using gh CLI:
       ```
       gh issue view {{ params.issue }} --json title,body,labels,assignees,milestone
       ```
    
    2. Extract requirements from issue:
       - Parse issue body for requirements
       - Identify acceptance criteria
       - Note any technical specifications
    
    3. Create feature branch:
       ```
       git checkout -b feature/issue-{{ params.issue }}-[short-description]
       ```
    
    ## File-Based Mode (Legacy)
    
    If only {{ params.description }} is provided:
    
    1. Generate a timestamp for the planning session
    2. Create the tasks directory structure:
       ```
       mkdir -p notes/tasks/[timestamp]_[description]/
       ```
    
    ## Feature Exploration
    
    Regardless of mode, conduct thorough requirements analysis:
    
    1. Ask the user to describe the feature at a high level (if not in issue)
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
    
    ### GitHub Issue Mode
    
    If using GitHub issues:
    
    1. Create a Feature Log comment on the parent issue:
       ```markdown
       ## Feature Log
       
       ### Planning Phase - [Current Date/Time]
       
       **Requirements Analysis:**
       [Summary of requirements discovered]
       
       **Technical Considerations:**
       [Key technical decisions and challenges]
       
       **Task Breakdown:**
       Creating [N] sub-issues for implementation...
       ```
    
    2. For each task, create a GitHub sub-issue:
       ```
       gh issue create \
         --title "[Parent #{{ params.issue }}] Task N: [Task Name]" \
         --body "[Task template content]" \
         --label "task,issue-{{ params.issue }}" \
         --milestone "[Same as parent]"
       ```
    
    3. Sub-issue template:
       ```markdown
       ## Context
       Parent Issue: #{{ params.issue }}
       Task [N] of [Total]
       
       ## Purpose
       [Brief explanation of what this task accomplishes]
       
       ## Scope
       **In Scope:**
       - [Specific items to complete]
       
       **Out of Scope:**
       - [Items for other tasks]
       
       ## Requirements
       - [Specific requirements for this task]
       
       ## Implementation Checklist
       - [ ] Write tests for [functionality]
       - [ ] Implement [specific feature]
       - [ ] Update documentation
       - [ ] Pass quality gates (format, test, credo)
       
       ## Acceptance Criteria
       - [Measurable completion criteria]
       
       ## Dependencies
       - Depends on: [Other task numbers if any]
       - Blocks: [Tasks that depend on this]
       ```
    
    4. Update parent issue with task list:
       ```markdown
       ## Implementation Tasks
       - [ ] #[sub-issue-1] - Task 1: [Name]
       - [ ] #[sub-issue-2] - Task 2: [Name]
       ...
       ```
    
    ### File-Based Mode
    
    If using file-based workflow, create files as before:
    
    1. Create an index file: `notes/tasks/[timestamp]_[description]/index.md`
    2. Create individual task files for each task
    
    ## Learning Capture
    
    During planning, capture insights:
    - Requirements that were unclear initially
    - Edge cases discovered through questioning  
    - Technical constraints identified
    - Patterns that might apply to future features
    
    If in GitHub mode, add these to the Feature Log comment.
    
    ## Important Guidelines
    
    1. Task Sizing:
       - Each task should be completable in a single focused work session
       - Tasks should have clear, measurable completion criteria
       - If a task seems too large, break it down further
    
    2. Dependency Management:
       - Order tasks to minimize dependencies between them
       - Clearly document any dependencies
       - Ensure the implementation sequence is technically feasible
    
    3. Task Clarity:
       - Each task should have a clear, specific purpose
       - Task boundaries should be explicit
       - Implementation checklists should be actionable and concrete
    
    ## Return Values
    
    For GitHub mode:
    - Parent issue number
    - List of created sub-issue numbers
    - Feature branch name
    
    For file mode:
    - Path to the tasks directory
    - Summary of tasks created
  </instructions>
</prompt>