# Radius Tokens

Huddlz uses a compact rounded vocabulary from the search/organize prototype.
Use named radius tokens instead of ad hoc Tailwind classes when styling
first-party surfaces.

| Token | Value | Use |
| --- | ---: | --- |
| `rounded-hz-tight` | `3px` | Tiny indicators and custom checkboxes where a 5px corner feels oversized. |
| `rounded-hz-control` | `5px` | Buttons, form fields, page tabs, sidebar tabs, badges, chips, pagination buttons, and progress tracks. |
| `rounded-hz-surface` | `7px` | Panels, cards, tables, dropdowns, popovers, and other framed page surfaces. |
| `rounded-hz-modal` | `7px` | Dialog containers and modal surfaces. This mirrors surfaces today but remains separate so dialogs can change later. |

DaisyUI theme radii map to the same visual scale:

- `--radius-selector`: `5px`
- `--radius-field`: `5px`
- `--radius-box`: `7px`

Prefer the `rounded-hz-*` utilities in app code. Keep `rounded-full` for true
circles and pills such as avatars, circular icon masks, and fully rounded user
menu triggers.
