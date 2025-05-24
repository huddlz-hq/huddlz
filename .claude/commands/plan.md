<prompt>
  <params>
    issue # GitHub issue number to plan from
  </params>

  <instructions>
    # Task Decomposition Planning
    
    This command analyzes a GitHub issue and breaks it down into manageable sub-tasks.
    
    ## Initial Setup
    
    1. Fetch issue details using gh CLI:
       ```
       gh issue view {{ params.issue }} --json title,body,labels,assignees,milestone
       ```
    
    2. Extract requirements from issue:
       - Parse issue body for requirements
       - Identify acceptance criteria
       - Note any technical specifications
       - Check for existing sub-issues
    
    3. Create feature branch:
       ```
       git checkout -b feature/issue-{{ params.issue }}-[short-description]
       ```
    
    ## Requirements Analysis
    
    Conduct thorough requirements analysis with PM mindset:
    
    1. Ask clarifying questions about the feature:
       - What problem does this solve for users?
       - Who are the primary users?
       - What specific actions should users be able to perform?
       - What are the constraints or limitations?
       - How does this integrate with existing features?
    
    2. Deep dive into specifics:
       - Data requirements: What information needs to be stored/displayed?
       - User flows: Walk through the typical user journey
       - Edge cases: What happens in unexpected scenarios?
       - Access control: Who can perform these actions?
       - Performance: Any specific performance requirements?
    
    3. Continue until you have:
       - Clear scope boundaries
       - Specific functional requirements
       - Non-functional requirements
       - Measurable success criteria
    
    ## Technical Assessment
    
    Analyze implementation needs:
    
    1. Data modeling:
       - Database schema changes
       - New Ecto schemas needed
       - Relationships between entities
    
    2. Business logic:
       - Ash actions required
       - Authorization policies
       - Validations and checks
    
    3. User interface:
       - LiveView components needed
       - Forms and interactions
       - Real-time updates
    
    4. Testing strategy:
       - Unit test scenarios
       - Integration test needs
       - Feature/behavior tests
    
    ## Task Breakdown
    
    1. Analyze requirements to identify discrete tasks:
       - Each task should be completable in one session
       - Tasks should have minimal dependencies
       - Clear boundaries between tasks
       - Logical implementation sequence
    
    2. Create Feature Log comment on parent issue:
       ```markdown
       ## Feature Log
       
       ### Planning Phase - [Current Date/Time]
       
       **Requirements Analysis:**
       - [Key requirements discovered]
       - [Clarifications obtained]
       - [Edge cases identified]
       
       **Technical Approach:**
       - [High-level implementation strategy]
       - [Key technical decisions]
       
       **Task Breakdown:**
       Creating [N] sub-issues for implementation...
       
       **Learning Capture:**
       - [Any insights from planning phase]
       - [Patterns to consider]
       ```
    
    3. For each task, create a GitHub sub-issue:
       ```
       gh issue create \
         --title "[#{{ params.issue }}] Task N: [Task Name]" \
         --body "[Task content]" \
         --label "task,parent-{{ params.issue }}" \
         --assignee "@me"
       ```
    
    4. Sub-issue template:
       ```markdown
       Parent Issue: #{{ params.issue }}
       Task [N] of [Total]
       
       ## Purpose
       [What this task accomplishes for the feature]
       
       ## Scope
       **Must Include:**
       - [Specific deliverables]
       - [Required functionality]
       
       **Explicitly Excludes:**
       - [Items for other tasks]
       - [Out of scope items]
       
       ## Implementation Checklist
       - [ ] Write tests for [specific functionality]
       - [ ] Implement [specific component/feature]
       - [ ] Update [specific documentation]
       - [ ] Ensure quality gates pass
       
       ## Technical Details
       - [Specific implementation notes]
       - [Files likely to be modified]
       - [Patterns to follow]
       
       ## Acceptance Criteria
       - [Specific, measurable criteria]
       - [User-visible outcomes]
       
       ## Dependencies
       - Requires: [Previous task numbers if any]
       - Blocks: [Subsequent tasks if any]
       ```
    
    5. Update parent issue with implementation plan:
       ```markdown
       ## Implementation Plan
       
       ### Tasks
       - [ ] #[sub-1] - [Name]: [Brief description]
       - [ ] #[sub-2] - [Name]: [Brief description]
       ...
       
       ### Sequence
       Tasks should be completed in order due to dependencies.
       
       ### Estimated Effort
       [Rough estimate based on task complexity]
       ```
    
    ## Learning Capture
    
    Document planning insights in Feature Log:
    - Requirements that were initially unclear
    - Technical challenges identified early
    - Patterns from similar features
    - Process improvements to consider
    
    ## Important Guidelines
    
    1. **Task Sizing**:
       - Aim for 2-4 hour tasks
       - If larger, break down further
       - Each task = one focused PR
    
    2. **Clear Boundaries**:
       - No overlap between tasks
       - Explicit scope statements
       - Clear handoff points
    
    3. **User Focus**:
       - Tasks deliver user value
       - Not just technical subdivisions
       - Testable outcomes
    
    ## Return Values
    
    - Parent issue: #{{ params.issue }}
    - Created sub-issues: [List of numbers]
    - Feature branch: [Branch name]
    - Next step: Start with first sub-issue using `/build`
  </instructions>
</prompt>