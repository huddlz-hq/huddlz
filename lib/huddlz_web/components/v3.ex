defmodule HuddlzWeb.V3 do
  @moduledoc """
  V3 design components facade.

  V3 is the third (and intentionally last) redesign of the huddlz UI; the
  clickthrough mockup at `/dev/design/clickthrough/*` is the design source
  of truth. Components defined under `HuddlzWeb.V3.*` mirror the v3
  vocabulary (`card`, `panel`, `chip`, `pill`, `row`, etc.) and are styled
  from `body.v3 { ... }` rules in `assets/css/app.css`.

  Importing this module brings every v3 function component into scope under
  a `v3_*` prefix (e.g. `<.v3_button>`, `<.v3_card>`, `<.v3_pill>`),
  avoiding collisions with the surviving daisy-styled components in
  `HuddlzWeb.CoreComponents` during the migration window.

  Phase 8 cleanup: drop the `v3_` prefix on these functions and flatten
  the namespace to `HuddlzWeb.Components.*` once `core_components.ex` is
  gone. See `~/.claude/plans/user-prompt-we-have-created-iterative-bird.md`
  for the full migration plan.
  """

  defmacro __using__(_opts) do
    quote do
      import HuddlzWeb.V3.Button
      import HuddlzWeb.V3.Card
      import HuddlzWeb.V3.Chip
      import HuddlzWeb.V3.Input
      import HuddlzWeb.V3.ListRow
      import HuddlzWeb.V3.Pagination
      import HuddlzWeb.V3.Panel
      import HuddlzWeb.V3.Pill
    end
  end
end
