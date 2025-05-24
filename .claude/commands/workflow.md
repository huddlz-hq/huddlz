<prompt>
  <instructions>
    # GitHub-Integrated Development Workflow
    
    This document outlines the streamlined development process using GitHub Issues for transparency and collaboration.
    
    ## Complete Workflow
    
    Feature development follows four phases, each activating a different cognitive mode:
    
    ### 1. Plan Phase (Project Manager Mode)
    
    Analyze a GitHub issue and break it down into manageable tasks:
    
    ```
    /plan issue=123
    ```
    
    This command:
    - Deep-dives into requirements with structured questions
    - Creates sub-issues for each discrete task
    - Establishes feature branch for development
    - Documents initial insights in Feature Log
    - Returns list of created sub-issues
    
    ### 2. Build Phase (Expert Engineer Mode)
    
    Implement each sub-issue with TDD/BDD discipline:
    
    ```
    /build issue=123-1
    ```
    
    This command:
    - Extracts requirements from sub-issue
    - Enforces test-first development
    - Updates progress in real-time via comments
    - Captures course corrections with 🔄 emoji
    - Enforces quality gates before completion
    - Requires user verification before proceeding
    
    Quality Gates (Mandatory):
    - `mix format` - Clean formatting
    - `mix test` - 100% passing
    - `mix credo --strict` - Zero issues
    - `mix test test/features/` - All scenarios pass
    
    ### 3. Verify Phase (Senior Reviewer Mode)
    
    Comprehensive review of the complete feature:
    
    ```
    /verify issue=123
    ```
    
    This command:
    - Reviews all sub-issues for completeness
    - Runs comprehensive quality checks
    - Tests integration and user experience
    - Documents findings in verification summary
    - Identifies issues by severity
    - Provides go/no-go decision
    
    ### 4. Reflect Phase (QA/Process Analyst Mode)
    
    Extract learnings from the complete journey:
    
    ```
    /reflect issue=123
    ```
    
    This command:
    - Analyzes entire development process
    - Identifies patterns and improvements
    - Updates LEARNINGS.md with insights
    - Creates follow-up issues
    - Proposes process enhancements
    - Posts reflection summary to issue
    
    ## GitHub Integration Features
    
    ### Feature Log
    A pinned comment on parent issues tracks all phases:
    - Planning discoveries
    - Building progress
    - Verification results
    - Reflection insights
    
    ### Progress Tracking
    Sub-issue comments provide real-time updates:
    - Completed items ✅
    - In-progress work 🔄
    - Quality gate status
    - Course corrections
    
    ### Learning Capture
    Continuous documentation of insights:
    - Requirements that emerged
    - Technical patterns discovered
    - Testing strategies that worked
    - Process improvements identified
    
    ## Workflow Benefits
    
    1. **Transparency**: All work visible in GitHub
    2. **Collaboration**: Team members can contribute
    3. **Traceability**: Complete audit trail
    4. **Learning**: Continuous improvement loop
    5. **Quality**: Enforced gates at every step
    
    ## Best Practices
    
    1. **Clear Issues**: Well-written issues improve planning
    2. **Atomic Tasks**: Each sub-issue = one PR
    3. **Real-time Updates**: Keep comments current
    4. **Capture Everything**: Document course corrections
    5. **Close the Loop**: Always run reflection
    
    ## Command Reference
    
    ```bash
    # Analyze and plan
    /plan issue=123
    
    # Build tasks sequentially
    /build issue=123-1
    /build issue=123-2
    
    # Verify complete feature
    /verify issue=123
    
    # Extract learnings
    /reflect issue=123
    ```
    
    ## Parallel Work Support
    
    Multiple AI instances can work on different sub-issues:
    - Each claims a sub-issue by commenting
    - Work proceeds independently
    - Verification ensures integration
    
    ## Important Notes
    
    - Never skip quality gates
    - Always write tests first
    - Document learnings immediately
    - Get user verification between tasks
    - Update LEARNINGS.md during reflection
    
    This workflow ensures consistent, high-quality development while building institutional knowledge over time.
  </instructions>
</prompt>