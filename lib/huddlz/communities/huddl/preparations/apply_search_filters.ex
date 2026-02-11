defmodule Huddlz.Communities.Huddl.Preparations.ApplySearchFilters do
  @moduledoc """
  Applies search filters to huddl queries including text search, date filtering, and event type filtering.
  """
  use Ash.Resource.Preparation
  require Ash.Query

  def prepare(query, _opts, _context) do
    query
    |> apply_text_filter()
    |> apply_date_filter()
    |> apply_event_type_filter()
    |> apply_location_filter()
  end

  defp apply_text_filter(query) do
    case Ash.Query.get_argument(query, :query) do
      nil ->
        query

      "" ->
        query

      search_query ->
        Ash.Query.filter(
          query,
          contains(title, ^search_query) or contains(description, ^search_query)
        )
    end
  end

  defp apply_date_filter(query) do
    date_filter = Ash.Query.get_argument(query, :date_filter)
    now = DateTime.utc_now()

    case date_filter do
      :upcoming ->
        # Include in-progress events
        Ash.Query.filter(query, ends_at > ^now)

      :this_week ->
        week_end = DateTime.add(now, 7 * 24 * 60 * 60, :second)
        Ash.Query.filter(query, ends_at > ^now and starts_at <= ^week_end)

      :this_month ->
        month_end = DateTime.add(now, 30 * 24 * 60 * 60, :second)
        Ash.Query.filter(query, ends_at > ^now and starts_at <= ^month_end)

      :past ->
        Ash.Query.filter(query, ends_at < ^now)

      :all ->
        query

      _ ->
        query
    end
  end

  defp apply_event_type_filter(query) do
    case Ash.Query.get_argument(query, :event_type) do
      nil -> query
      event_type -> Ash.Query.filter(query, event_type == ^event_type)
    end
  end

  defp apply_location_filter(query) do
    lat = Ash.Query.get_argument(query, :search_latitude)
    lng = Ash.Query.get_argument(query, :search_longitude)
    distance_miles = Ash.Query.get_argument(query, :distance_miles)

    if lat && lng do
      distance_meters = (distance_miles || 25) * 1609.344

      Ash.Query.filter(
        query,
        fragment(
          "ST_DWithin(ST_SetSRID(ST_MakePoint(?, ?), 4326)::geography, ST_SetSRID(ST_MakePoint(?, ?), 4326)::geography, ?)",
          longitude,
          latitude,
          ^lng,
          ^lat,
          ^distance_meters
        )
      )
    else
      query
    end
  end
end
