defmodule HuddlzWeb.Components.ListRow do
  @moduledoc """
  V3 row-list — flexible row layout used in member rosters, notification
  inboxes, settings pages, and help-center sections.

  Wrap multiple rows in a `<div class="row-list">` and use `list_row/1`
  for each item.
  """
  use Phoenix.Component

  attr :class, :any, default: nil
  attr :rest, :global

  slot :inner_block, required: true

  def list_row(assigns) do
    ~H"""
    <div class={["row", @class]} {@rest}>
      {render_slot(@inner_block)}
    </div>
    """
  end
end
