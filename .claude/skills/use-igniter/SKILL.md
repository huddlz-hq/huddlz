---
name: use-igniter
description: "A code generation and project patching framework."
metadata:
  managed-by: usage-rules
---

<!-- usage-rules-skill-start -->
## Additional References

- [igniter](references/igniter.md)

## Searching Documentation

```sh
mix usage_rules.search_docs "search term" -p igniter
```

## Available Mix Tasks

- `mix igniter.add` - Adds the provided deps to `mix.exs`
- `mix igniter.add_extension` - Adds an extension to your `.igniter.exs` configuration file.
- `mix igniter.apply_upgrades` - Applies the upgrade scripts for the list of package version changes provided.
- `mix igniter.gen.task` - Generates a new igniter task
- `mix igniter.install` - Install a package or packages, and run any associated installers.
- `mix igniter.move_files` - Moves any relevant files to their 'correct' location.
- `mix igniter.phx.install`
- `mix igniter.refactor.rename_function` - Rename functions across a project with automatic reference updates.
- `mix igniter.refactor.unless_to_if_not` - Rewrites occurrences of `unless x` to `if !x` across the project.
- `mix igniter.remove` - Removes the provided deps from `mix.exs`
- `mix igniter.setup` - Creates or updates a .igniter.exs file, used to configure Igniter for end user's preferences.
- `mix igniter.update_gettext` - Applies changes to resolve a warning introduced in gettext 0.26.0
- `mix igniter.upgrade` - Fetch and upgrade dependencies. A drop in replacement for `mix deps.update` that also runs upgrade tasks.
- `mix igniter.upgrade_igniter`
<!-- usage-rules-skill-end -->
