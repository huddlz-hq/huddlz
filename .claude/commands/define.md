<prompt>
  <params>
    id # Feature identifier (e.g., "0001" or descriptive slug like "signup-flow")
    title # Descriptive title of the feature
  </params>

  <s>
    When defining feature requirements, follow a structured approach to ensure clarity and completeness.
    A well-written requirements document provides clear direction for development while allowing flexibility in implementation.
    Focus on the "what" and "why" rather than the "how" of implementation.
    Use consistent ID formats and descriptive titles to make documents easily identifiable.
  </s>

  <instructions>
    # Requirements Definition Process
    Follow these steps to create a comprehensive feature requirements document:

    ## Phase 1: Initial Setup
    1. Format the feature ID and create a filename:
       - Use the provided ID: {{ params.id }}
       - Create a filename in format: `docs/requirements/[ID]_[title_slug].md`
       - Where [title_slug] is {{ params.title }} converted to lowercase with spaces replaced by underscores
       - Remove special characters
       - Example: With ID "0001" and title "List Events", file becomes "0001_list_events.md"
    2. Create directory if it doesn't exist: `mkdir -p docs/requirements`
    3. If the ID is numeric, check it doesn't conflict with existing documents:
       - List existing requirements: `ls docs/requirements/*.md`
       - If no requirements documents exist, start with 0001
       - Otherwise, find the highest number and increment by 1
       - Always use four digits with leading zeros (0001, 0002, etc.)
    4. Determine the full path for the requirements file: `docs/requirements/[id]_[title_slug].md`
       - Example: `docs/requirements/0001_list_events.md`
    5. Create a temporary working file to prepare the requirements content

    ## Phase 2: Problem Definition
    1. Ask the user to describe the problem this feature will solve
    2. Clarify who the primary users or stakeholders are
    3. Determine how this feature aligns with broader project goals
    4. Ask about any known constraints or limitations
    5. Identify the key pain points being addressed

    ## Phase 3: Requirements Gathering
    1. Ask the user about specific functional requirements
    2. Inquire about non-functional requirements (performance, security, etc.)
    3. Discuss acceptance criteria for the feature
    4. Ask about related features or dependencies
    5. Identify potential edge cases or special conditions
    6. Document any technical constraints or preferences

    ## Phase 4: User Experience
    1. Ask about user workflows or user journeys
    2. Discuss the expected user interactions
    3. Identify potential UX improvements or considerations
    4. Ask about any specific design requirements or preferences

    ## Phase 5: Requirements Document Creation
    Create a comprehensive requirements document using this structure:

    ```markdown
    # {{ params.title }} - Requirements Document

    ## Version Information
    - Requirements ID: {{ params.id }}
    - Date Created: [Current Date]
    - Version: 1.0
    - Author: [User]
    - Status: Draft

    ## 1. Overview
    ### 1.1 Problem Statement
    [Concise description of the problem this feature solves]

    ### 1.2 User Need
    [Description of who needs this feature and why]

    ### 1.3 Business Objectives
    [Description of how this feature aligns with business goals]

    ## 2. Requirements
    ### 2.1 Functional Requirements
    [Numbered list of specific functional requirements]

    ### 2.2 Non-Functional Requirements
    [Performance, security, scalability, usability, etc.]

    ### 2.3 Constraints
    [Technical, business, legal, or other constraints]

    ## 3. User Experience
    ### 3.1 User Journey
    [Step-by-step description of how users will interact with the feature]

    ### 3.2 UI/UX Considerations
    [Specific UI/UX requirements or preferences]

    ## 4. Technical Considerations
    ### 4.1 System Components
    [Major components affected or involved]

    ### 4.2 Dependencies
    [Other features, systems, or services this feature depends on]

    ### 4.3 Integration Points
    [How this feature integrates with existing systems]

    ## 5. Acceptance Criteria
    [Numbered list of specific, testable criteria that define when the feature is complete]

    ## 6. Out of Scope
    [Clearly defined boundaries - what this feature does NOT include]

    ## 7. Future Considerations
    [Potential future enhancements or related features]

    ## 8. References
    [Links to related documents, conversations, or resources]
    ```

    ## Phase 6: Review and Finalization
    1. Review the draft requirements document for completeness and clarity
    2. Check for any missing information or ambiguities
    3. Ensure all sections are appropriately detailed
    4. Ask the user for feedback and make necessary adjustments
    5. Save the final document to the designated location: `docs/requirements/{{ params.id }}_[title_slug].md`
    6. Provide a summary of the document content and next steps

    # Important Guidelines
    - Focus on WHAT needs to be done, not HOW to implement it
    - Use clear, specific language avoiding ambiguous terms
    - Make requirements testable whenever possible
    - Use numbered lists for requirements to make them easily referenceable
    - Prioritize requirements if appropriate (must-have, should-have, nice-to-have)
    - Include diagrams or mockups when they add clarity (using MermaidJS)
    - Separate requirements (what) from implementation details (how)
    - Be specific about user workflows and journeys
    - Define clear acceptance criteria for each requirement
    - Address edge cases and error scenarios
    - Specify performance expectations when relevant
    - Clearly define what is out of scope
    - Use consistent terminology throughout the document
    - Avoid technical jargon unless necessary
    - Consider security and privacy implications
    - Include accessibility requirements when applicable
    - Document assumptions explicitly
    - Be concise but thorough
  </instructions>
</prompt>