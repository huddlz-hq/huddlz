defmodule HuddlzWeb.Components.Pagination do
  @moduledoc """
  V3 pagination — `<nav class="pagination">` with prev/next page-nav buttons
  flanking an `<ol class="page-numbers">`. Page-number entries collapse to an
  ellipsis when the total exceeds 7.

  Supply `page_path` for crawlable LiveView patch links, or `event_name` for
  pagination managed entirely by the host LiveView.
  """
  use Phoenix.Component

  attr :current_page, :integer, required: true
  attr :total_pages, :integer, required: true

  attr :event_name, :string,
    default: nil,
    doc: "phx-click event name dispatched to the LiveView"

  attr :page_path, :any, default: nil, doc: "Function mapping a page number to a URL"

  attr :id, :string, default: "pagination"
  attr :class, :any, default: nil

  def pagination(assigns) do
    ~H"""
    <nav id={@id} class={["pagination", @class]} aria-label="Pagination">
      <.page_control
        class="page-nav"
        disabled={@current_page <= 1}
        id={@id <> "-previous"}
        aria-label="Previous page"
        event_name={@event_name}
        page_path={@page_path}
        page={@current_page - 1}
      >
        <svg
          width="14"
          height="14"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          stroke-width="2"
          stroke-linecap="round"
          stroke-linejoin="round"
        >
          <path d="m15 18-6-6 6-6" />
        </svg>
        <span>Prev</span>
      </.page_control>
      <ol class="page-numbers">
        <%= for entry <- pagination_range(@current_page, @total_pages) do %>
          <%= if entry == :ellipsis do %>
            <li class="page-ellipsis" aria-hidden="true">…</li>
          <% else %>
            <li>
              <.page_control
                class={["page-num", entry == @current_page && "is-active"]}
                id={@id <> "-page-#{entry}"}
                aria-current={entry == @current_page && "page"}
                event_name={@event_name}
                page_path={@page_path}
                page={entry}
              >
                {entry}
              </.page_control>
            </li>
          <% end %>
        <% end %>
      </ol>
      <.page_control
        class="page-nav"
        disabled={@current_page >= @total_pages}
        id={@id <> "-next"}
        aria-label="Next page"
        event_name={@event_name}
        page_path={@page_path}
        page={@current_page + 1}
      >
        <span>Next</span>
        <svg
          width="14"
          height="14"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          stroke-width="2"
          stroke-linecap="round"
          stroke-linejoin="round"
        >
          <path d="m9 6 6 6-6 6" />
        </svg>
      </.page_control>
    </nav>
    """
  end

  attr :page_path, :any, default: nil
  attr :event_name, :string, default: nil
  attr :page, :integer, required: true
  attr :disabled, :boolean, default: false
  attr :rest, :global, include: ~w(aria-label aria-current)
  slot :inner_block, required: true

  defp page_control(assigns) do
    ~H"""
    <%= if @page_path && !@disabled do %>
      <.link patch={@page_path.(@page)} {@rest}>{render_slot(@inner_block)}</.link>
    <% else %>
      <button
        type="button"
        disabled={@disabled}
        phx-click={@event_name}
        phx-value-page={@page}
        {@rest}
      >
        {render_slot(@inner_block)}
      </button>
    <% end %>
    """
  end

  defp pagination_range(_current, total) when total <= 7, do: Enum.to_list(1..total)

  defp pagination_range(current, total) do
    cond do
      current <= 4 -> [1, 2, 3, 4, 5, :ellipsis, total]
      current >= total - 3 -> [1, :ellipsis, total - 4, total - 3, total - 2, total - 1, total]
      true -> [1, :ellipsis, current - 1, current, current + 1, :ellipsis, total]
    end
  end
end
