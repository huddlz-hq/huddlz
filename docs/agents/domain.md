# Domain Docs

This repository uses a single-context domain layout.

## Before exploring, read these

- `CONTEXT.md` at the repository root.
- Relevant ADRs under `docs/adr/`.

If a file or directory does not exist, proceed silently. Domain-modeling workflows create them lazily when decisions are resolved.

## Structure

```text
/
├── CONTEXT.md
└── docs/
    └── adr/
```

## Use the glossary vocabulary

Use the terms defined in `CONTEXT.md` in issue titles, specifications, tests, documentation, and code-facing descriptions. Avoid synonyms the glossary explicitly rejects.

If a required concept is missing, reconsider the terminology or raise the gap through domain modeling.

## Flag ADR conflicts

Explicitly identify when proposed work contradicts an existing ADR rather than silently overriding it.
