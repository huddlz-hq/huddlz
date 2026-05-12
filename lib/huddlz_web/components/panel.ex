defmodule HuddlzWeb.Components.Panel do
  @moduledoc """
  V3 panel surface — bordered container with optional `panel-head` (h2 + pill)
  and `panel-sub` (subtitle).

  ```
  <.panel>
    <:head>
      <h2>Members</h2>
    </:head>
    <:sub>43 active this week</:sub>
    Panel content here.
  </.panel>
  ```
  """
  use Phoenix.Component

  attr :class, :any, default: nil
  attr :rest, :global

  slot :head, doc: "panel header content (h2 + optional trailing pill)"
  slot :sub, doc: "subtitle text rendered under the head"
  slot :inner_block, required: true

  def panel(assigns) do
    ~H"""
    <section class={["panel", @class]} {@rest}>
      <header :if={@head != []} class="panel-head">
        {render_slot(@head)}
      </header>
      <p :if={@sub != []} class="panel-sub">{render_slot(@sub)}</p>
      {render_slot(@inner_block)}
    </section>
    """
  end
end
