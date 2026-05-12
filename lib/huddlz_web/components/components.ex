defmodule HuddlzWeb.Components do
  @moduledoc """
  Design components facade.

  Each function component (`<.avatar>`, `<.button>`, `<.card>`, `<.chip>`,
  `<.flash>`, `<.icon>`, `<.input>`, `<.list_row>`, `<.modal>`,
  `<.pagination>`, `<.panel>`, `<.pill>`) lives in its own module under this
  namespace and renders the vocabulary from the clickthrough mockup at
  `/dev/design/clickthrough/*`. Styles live in `assets/css/app.css`.

  Importing this module via `use HuddlzWeb.Components` brings every
  function component into scope at once. It's wired up in
  `HuddlzWeb.html_helpers/0`.
  """

  defmacro __using__(_opts) do
    quote do
      import HuddlzWeb.Components.Avatar
      import HuddlzWeb.Components.Button
      import HuddlzWeb.Components.Card
      import HuddlzWeb.Components.Chip
      import HuddlzWeb.Components.Flash
      import HuddlzWeb.Components.Icon
      import HuddlzWeb.Components.Input
      import HuddlzWeb.Components.ListRow
      import HuddlzWeb.Components.Modal
      import HuddlzWeb.Components.Pagination
      import HuddlzWeb.Components.Panel
      import HuddlzWeb.Components.Pill
    end
  end
end
