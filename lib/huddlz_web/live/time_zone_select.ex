defmodule HuddlzWeb.Live.TimeZoneSelect do
  @moduledoc """
  A searchable time zone picker LiveComponent.

  Renders a curated shortlist of North American and European zones up
  front (the common case for this app's users), with a search box and an
  optional "show all time zones" expansion — grouped by region — for
  everything else. Each row shows the zone's live UTC offset, computed at
  render time so it stays correct across DST transitions.

  Reads and writes its value through a `Phoenix.HTML.FormField`, exactly
  like `<.select>`: pass `field={@form[:time_zone]}`. When `prompt` is set,
  a pinned row at the top of the list clears the field back to blank (e.g.
  "auto-detect from location"); omit it for a field that must always carry
  a zone.

  Renders a hidden `<input>` so the field's value round-trips on the
  enclosing `<form>`'s native submit, but picking a zone here updates the
  parent's `AshPhoenix.Form` immediately via a `{:time_zone_selected, id,
  zone_id}` / `{:time_zone_cleared, id}` message — the same pattern as
  `HuddlzWeb.Live.LocationAutocomplete` and `HuddlzWeb.Live.SavedLocationPicker`.
  """
  use HuddlzWeb, :live_component

  alias HuddlzWeb.Live.Helpers.TimeZoneOptions
  alias Phoenix.HTML.FormField

  # Curated shortlist for North America and Europe. Labels avoid baking in
  # UTC offsets (those shift with DST) — the offset is computed live
  # instead, per render, so it never goes stale.
  @common_zones [
    %{id: "America/New_York", label: "Eastern Time", sub: "New York, Toronto"},
    %{id: "America/Chicago", label: "Central Time", sub: "Chicago, Dallas"},
    %{id: "America/Denver", label: "Mountain Time", sub: "Denver, Salt Lake City"},
    %{id: "America/Phoenix", label: "Arizona", sub: "Phoenix (no DST)"},
    %{id: "America/Los_Angeles", label: "Pacific Time", sub: "Los Angeles, Seattle"},
    %{id: "America/Anchorage", label: "Alaska", sub: "Anchorage"},
    %{id: "Pacific/Honolulu", label: "Hawaii", sub: "Honolulu (no DST)"},
    %{id: "America/Halifax", label: "Atlantic Time", sub: "Halifax"},
    %{id: "Europe/London", label: "London", sub: "UK, Ireland"},
    %{id: "Europe/Paris", label: "Central Europe", sub: "Paris, Berlin, Madrid"},
    %{id: "Europe/Athens", label: "Eastern Europe", sub: "Athens, Helsinki"},
    %{id: "Etc/UTC", label: "UTC", sub: "Coordinated Universal Time"}
  ]

  @impl true
  def mount(socket) do
    {:ok, assign(socket, search_text: "", show_dropdown: false, show_all: false)}
  end

  attr :id, :string, required: true
  attr :field, FormField, required: true
  attr :label, :string, default: nil
  attr :prompt, :string, default: nil
  attr :help, :string, default: nil

  @impl true
  def render(assigns) do
    query = String.trim(assigns.search_text)
    searching? = query != ""
    common = filter_common(query)
    grouped_all = filtered_all_grouped(query, assigns.show_all)
    selected_id = normalize(assigns.field.value)

    assigns =
      assigns
      |> assign(:searching?, searching?)
      |> assign(:common, common)
      |> assign(:grouped_all, grouped_all)
      |> assign(:nothing_found?, searching? and common == [] and grouped_all == [])
      |> assign(:selected_id, selected_id)
      |> assign(:trigger_label, trigger_label(selected_id, assigns.prompt))
      |> assign(:trigger_sub, trigger_sub(selected_id))
      |> assign(:trigger_offset, selected_id && offset_label(selected_id))
      |> assign(:all_count, length(all_zone_ids()))

    ~H"""
    <div id={@id} class="form-row tz-select" phx-click-away="dismiss" phx-target={@myself}>
      <label :if={@label} class="form-label" for={"#{@id}-trigger"}>{@label}</label>

      <input type="hidden" name={@field.name} id={@field.id} value={@field.value} />

      <button
        type="button"
        id={"#{@id}-trigger"}
        class="tz-select-trigger"
        phx-click="toggle"
        phx-target={@myself}
        aria-haspopup="listbox"
        aria-expanded={to_string(@show_dropdown)}
      >
        <span class="tz-select-trigger-text">
          <span class={["tz-select-trigger-label", @trigger_sub == nil && "is-placeholder"]}>
            {@trigger_label}
          </span>
          <span :if={@trigger_sub} class="tz-select-trigger-sub">
            {@trigger_sub}<span :if={@trigger_offset}> · {@trigger_offset}</span>
          </span>
        </span>
        <.icon
          name="hero-chevron-down"
          class={"tz-select-chevron" <> (@show_dropdown && " is-open" || "")}
        />
      </button>

      <div :if={@show_dropdown} class="tz-select-panel">
        <div class="tz-select-search">
          <.icon name="hero-magnifying-glass" class="tz-select-search-icon" />
          <input
            type="text"
            value={@search_text}
            placeholder="Search city, region, or zone…"
            phx-change="search"
            phx-target={@myself}
            phx-debounce="150"
            name={"#{@id}_search"}
            autocomplete="off"
          />
        </div>

        <div class="tz-select-list" role="listbox">
          <button
            :if={@prompt}
            type="button"
            class="tz-select-option is-prompt"
            phx-click="clear"
            phx-target={@myself}
          >
            {@prompt}
          </button>

          <p :if={@nothing_found?} class="tz-select-empty">No matching time zones</p>

          <div :if={!@nothing_found? and @common != []}>
            <div class="tz-select-group-label">Common</div>
            <button
              :for={z <- @common}
              type="button"
              class={["tz-select-option", z.id == @selected_id && "is-selected"]}
              phx-click="select"
              phx-value-id={z.id}
              phx-target={@myself}
            >
              <span class="tz-select-option-text">
                <span class="opt-main">{z.label}</span>
                <span class="opt-secondary">{z.sub}</span>
              </span>
              <span class="tz-select-option-meta">
                <span class="tz-select-offset">{offset_label(z.id)}</span>
                <.icon :if={z.id == @selected_id} name="hero-check" class="tz-select-check" />
              </span>
            </button>
          </div>

          <div :for={{region, ids} <- @grouped_all}>
            <div class="tz-select-group-label">{region}</div>
            <button
              :for={zone_id <- ids}
              type="button"
              class={["tz-select-option", zone_id == @selected_id && "is-selected"]}
              phx-click="select"
              phx-value-id={zone_id}
              phx-target={@myself}
            >
              <span class="tz-select-option-text">
                <span class="opt-main">{city_label(zone_id)}</span>
                <span class="opt-secondary">{zone_id}</span>
              </span>
              <span class="tz-select-option-meta">
                <span class="tz-select-offset">{offset_label(zone_id)}</span>
                <.icon :if={zone_id == @selected_id} name="hero-check" class="tz-select-check" />
              </span>
            </button>
          </div>

          <button
            :if={!@searching? and !@show_all}
            type="button"
            class="tz-select-show-all"
            phx-click="show_all"
            phx-target={@myself}
          >
            <.icon name="hero-globe-alt" class="tz-select-show-all-icon" />
            Show all time zones ({@all_count})
          </button>
        </div>
      </div>

      <p :if={@help} class="form-help">{@help}</p>
      <.field_errors field={@field} />
    </div>
    """
  end

  @impl true
  def handle_event("toggle", _params, socket) do
    {:noreply, update(socket, :show_dropdown, &(!&1))}
  end

  @impl true
  def handle_event("search", params, socket) do
    text = params[socket.assigns.id <> "_search"] || ""
    {:noreply, assign(socket, search_text: text, show_dropdown: true)}
  end

  @impl true
  def handle_event("show_all", _params, socket) do
    {:noreply, assign(socket, show_all: true)}
  end

  @impl true
  def handle_event("select", %{"id" => zone_id}, socket) do
    send(self(), {:time_zone_selected, socket.assigns.id, zone_id})
    {:noreply, close_dropdown(socket)}
  end

  @impl true
  def handle_event("clear", _params, socket) do
    send(self(), {:time_zone_cleared, socket.assigns.id})
    {:noreply, close_dropdown(socket)}
  end

  @impl true
  def handle_event("dismiss", _params, socket) do
    {:noreply, close_dropdown(socket)}
  end

  defp close_dropdown(socket) do
    assign(socket, show_dropdown: false, search_text: "", show_all: false)
  end

  defp filter_common(""), do: @common_zones

  defp filter_common(query) do
    q = String.downcase(query)

    Enum.filter(@common_zones, fn z ->
      String.contains?(String.downcase(z.label), q) or
        String.contains?(String.downcase(z.sub), q) or
        String.contains?(String.downcase(z.id), q)
    end)
  end

  defp filtered_all_grouped("", false), do: []

  defp filtered_all_grouped(query, show_all) do
    ids = all_zone_ids()

    matches =
      case query do
        "" -> if show_all, do: ids, else: []
        q -> Enum.filter(ids, &matches_query?(&1, String.downcase(q)))
      end

    matches
    |> Enum.group_by(&region_of/1)
    |> Enum.sort_by(fn {region, _ids} -> region end)
    |> Enum.map(fn {region, ids} -> {region, Enum.sort_by(ids, &city_label/1)} end)
  end

  defp matches_query?(zone_id, q) do
    String.contains?(String.downcase(zone_id), q) or
      String.contains?(String.downcase(city_label(zone_id)), q) or
      String.contains?(String.downcase(region_of(zone_id)), q)
  end

  defp all_zone_ids, do: Enum.map(TimeZoneOptions.options(), &elem(&1, 0))

  defp region_of(zone_id) do
    case String.split(zone_id, "/", parts: 2) do
      [region, _rest] -> region
      [region] -> region
    end
  end

  defp city_label(zone_id) do
    zone_id
    |> String.split("/")
    |> List.last()
    |> String.replace("_", " ")
  end

  defp trigger_label(nil, prompt) when is_binary(prompt), do: prompt
  defp trigger_label(nil, nil), do: "Select a time zone…"

  defp trigger_label(zone_id, _prompt) do
    case Enum.find(@common_zones, &(&1.id == zone_id)) do
      %{label: label} -> label
      nil -> city_label(zone_id)
    end
  end

  defp trigger_sub(nil), do: nil

  defp trigger_sub(zone_id) do
    case Enum.find(@common_zones, &(&1.id == zone_id)) do
      %{sub: sub} -> sub
      nil -> zone_id
    end
  end

  defp offset_label(zone_id) do
    case DateTime.now(zone_id) do
      {:ok, datetime} -> format_offset(datetime.utc_offset + datetime.std_offset)
      {:error, _reason} -> nil
    end
  end

  defp format_offset(0), do: "UTC"

  defp format_offset(seconds) do
    sign = if seconds >= 0, do: "+", else: "-"
    total_minutes = div(abs(seconds), 60)
    hours = total_minutes |> div(60) |> Integer.to_string() |> String.pad_leading(2, "0")
    minutes = total_minutes |> rem(60) |> Integer.to_string() |> String.pad_leading(2, "0")
    "UTC#{sign}#{hours}:#{minutes}"
  end

  defp normalize(nil), do: nil
  defp normalize(""), do: nil
  defp normalize(value), do: value
end
