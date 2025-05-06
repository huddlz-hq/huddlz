<prompt>
  <params>
    notes_file # Path to the feature notes file to analyze
    update_learnings # Whether to update the central LEARNINGS.md (true/false, default true)
  </params>

  <instructions>
    # Reflection Process
    
    This command analyzes completed work to extract learnings and improve future development.
    
    ## Reflection Analysis
    
    1. Read the specified notes file: {{ params.notes_file }}
    2. Analyze the entire development process, focusing on:
       - Key decisions made and their outcomes
       - Challenges encountered and how they were addressed
       - Architectural or design patterns that worked well
       - Patterns that caused issues or needed reworking
       - Testing approaches and their effectiveness
       - Techniques that improved efficiency or quality
    
    ## Knowledge Extraction
    
    3. Add insights to the "Learnings" section of {{ params.notes_file }}:
       - Organize learnings by categories (e.g., Design, Implementation, Testing)
       - Use clear, actionable language
       - Include concrete examples
       - Focus on transferable knowledge
    
    ## Global Knowledge Integration
    
    4. If {{ params.update_learnings }} is true:
       - Open and read the central LEARNINGS.md file
       - Identify categories where new learnings should be added
       - Add new insights in appropriate sections
       - Ensure there are no duplicates
       - Maintain consistent formatting
    
    ## Improvement Recommendations
    
    5. Based on the reflection:
       - Suggest updates to project documentation
       - Identify patterns that should be formalized
       - Recommend tooling or process improvements
       - Highlight areas where additional resources would help
    
    ## Important Rules
    
    - Be specific and concrete in identifying learnings
    - Focus on actionable insights, not just observations
    - Consider both technical and process improvements
    - Look for patterns across multiple features
    - Separate one-off issues from systemic patterns
    - Keep the LEARNINGS.md file well-organized with clear categories
    - When adding to LEARNINGS.md, maintain a consistent style
    
    ## Return Values
    
    Summarize the key learnings identified and any changes made to documentation.
  </instructions>
</prompt>