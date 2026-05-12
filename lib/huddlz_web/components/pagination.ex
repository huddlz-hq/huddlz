defmodule HuddlzWeb.Components.Pagination do
  @moduledoc """
  V3 pagination — `<nav class="pagination">` with prev/next page-nav buttons
  flanking an `<ol class="page-numbers">`. Page-number entries collapse to an
  ellipsis when the total exceeds 7.

  Pages are emitted as `<button>` elements that fire a `phx-click` event with
  `phx-value-page=N`; the host LiveView pushes the corresponding patch URL.
  """
  use Phoenix.Component

  attr :current_page, :integer, required: true
  attr :total_pages, :integer, required: true

  attr :event_name, :string,
    required: true,
    doc: "phx-click event name dispatched to the LiveView"

  attr :class, :any, default: nil

  def pagination(assigns) do
    ~H"""
    <nav class={["pagination", @class]} aria-label="Pagination">
      <button
        type="button"
        class="page-nav"
        disabled={@current_page <= 1}
        aria-label="Previous page"
        phx-click={@event_name}
        phx-value-page={@current_page - 1}
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
      </button>
      <ol class="page-numbers">
        <%= for entry <- pagination_range(@current_page, @total_pages) do %>
          <%= if entry == :ellipsis do %>
            <li class="page-ellipsis" aria-hidden="true">…</li>
          <% else %>
            <li>
              <button
                type="button"
                class={["page-num", entry == @current_page && "is-active"]}
                aria-current={entry == @current_page && "page"}
                phx-click={@event_name}
                phx-value-page={entry}
              >
                {entry}
              </button>
            </li>
          <% end %>
        <% end %>
      </ol>
      <button
        type="button"
        class="page-nav"
        disabled={@current_page >= @total_pages}
        aria-label="Next page"
        phx-click={@event_name}
        phx-value-page={@current_page + 1}
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
      </button>
    </nav>
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
