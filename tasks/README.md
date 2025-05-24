# Task Management Directory

This directory contains detailed planning and implementation notes for feature development using the hybrid workflow documented in CLAUDE.md.

## Purpose

These task files serve as:
- **Living documentation** of feature development
- **Decision history** including course corrections (🔄)
- **Knowledge capture** for future reference
- **Work continuity** across sessions and machines

## Structure

Each issue gets its own directory: `tasks/issue-NUMBER/`

```
tasks/issue-123/
├── index.md          # Requirements, plan, and progress tracking
├── session.md        # Real-time implementation notes and learnings
├── tasks/            # Individual task files with specific scope
├── learnings.md      # Accumulated insights (created during reflection)
├── RESUME.md         # Quick reference for picking up work later
└── pr-description.md # PR template (created during reflection)
```

## Key Benefits

1. **Course Corrections**: We document when approaches change and why
2. **Learning Capture**: Insights are recorded as they happen, not reconstructed later
3. **Work Portability**: Switch machines or contexts without losing momentum
4. **Historical Value**: Understand not just what was built, but why decisions were made

## Example

See `issue-19/` for a real example where we discovered a dependency on issue #20 during planning and properly deferred the work. The session notes show the discovery process and reasoning.

## Note

These files are committed to the repository as they contain valuable project knowledge and demonstrate thoughtful development practices. Issues marked "ON HOLD" are not abandoned - they're properly sequenced based on dependencies.