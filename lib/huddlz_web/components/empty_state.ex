defmodule HuddlzWeb.Components.EmptyState do
  @moduledoc """
  Empty state — a dashed, centered placeholder shown where a list has
  nothing to render. Pairs a hero icon with a short title, one line of
  guidance, and an optional action.
  """
  use Phoenix.Component

  import HuddlzWeb.Components.Icon

  attr :title, :string, required: true
  attr :icon, :string, default: nil, doc: ~s(hero icon name, e.g. "hero-magnifying-glass")
  attr :class, :any, default: nil
  attr :rest, :global

  slot :inner_block, doc: "one line of guidance, rendered as a paragraph"
  slot :action, doc: "an optional button or link"

  def empty_state(assigns) do
    ~H"""
    <div class={["empty-state", @class]} {@rest}>
      <span :if={@icon} class="empty-state-icon" aria-hidden="true">
        <.icon name={@icon} class="size-5" />
      </span>
      <h3>{@title}</h3>
      <p :if={@inner_block != []}>{render_slot(@inner_block)}</p>
      <div :if={@action != []} class="empty-state-action">{render_slot(@action)}</div>
    </div>
    """
  end
end
