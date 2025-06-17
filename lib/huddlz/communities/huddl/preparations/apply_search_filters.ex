defmodule Huddlz.Communities.Huddl.Preparations.ApplySearchFilters do
  @moduledoc """
  Applies date and type filters to huddl queries based on arguments.
  """
  use Ash.Resource.Preparation

  require Ash.Query

  def prepare(query, _opts, _context) do
    query
    |> apply_keyword_filter()
    |> apply_location_filter()
    |> apply_date_filter()
    |> apply_type_filter()
    |> apply_status_filter()
    |> apply_sorting()
  end

  defp apply_keyword_filter(query) do
    case Ash.Query.get_argument(query, :query) do
      nil ->
        query

      "" ->
        query

      keyword ->
        Ash.Query.filter(query, contains(title, ^keyword) or contains(description, ^keyword))
    end
  end

  defp apply_location_filter(query) do
    lat = Ash.Query.get_argument(query, :latitude)
    lng = Ash.Query.get_argument(query, :longitude)
    radius = Ash.Query.get_argument(query, :radius_miles)

    if lat && lng do
      Ash.Query.filter(
        query,
        fragment(
          "ST_DWithin(?::geography, ST_MakePoint(?, ?)::geography, ?)",
          coordinates,
          ^lng,
          ^lat,
          ^radius * 1609.34
        )
      )
    else
      query
    end
  end

  defp apply_date_filter(query) do
    filter = Ash.Query.get_argument(query, :date_filter)
    apply_specific_date_filter(query, filter)
  end

  defp apply_specific_date_filter(query, filter) when filter in [nil, :any_day] do
    Ash.Query.filter(query, ends_at > now())
  end

  defp apply_specific_date_filter(query, :past_events) do
    Ash.Query.filter(query, ends_at < now())
  end

  defp apply_specific_date_filter(query, :starting_soon) do
    Ash.Query.filter(
      query,
      starts_at > now() and starts_at <= fragment("NOW() + INTERVAL '7 days'")
    )
  end

  defp apply_specific_date_filter(query, :today) do
    Ash.Query.filter(query, fragment("DATE(?)", starts_at) == fragment("CURRENT_DATE"))
  end

  defp apply_specific_date_filter(query, :tomorrow) do
    Ash.Query.filter(
      query,
      fragment("DATE(?)", starts_at) == fragment("CURRENT_DATE + INTERVAL '1 day'")
    )
  end

  defp apply_specific_date_filter(query, :this_week) do
    Ash.Query.filter(
      query,
      starts_at > now() and starts_at <= fragment("NOW() + INTERVAL '7 days'")
    )
  end

  defp apply_specific_date_filter(query, :this_weekend) do
    Ash.Query.filter(
      query,
      fragment("DATE_TRUNC('week', NOW()) + INTERVAL '5 days'") <= starts_at and
        starts_at < fragment("DATE_TRUNC('week', NOW()) + INTERVAL '7 days'")
    )
  end

  defp apply_specific_date_filter(query, :next_week) do
    Ash.Query.filter(
      query,
      fragment("DATE_TRUNC('week', NOW()) + INTERVAL '1 week'") <= starts_at and
        starts_at < fragment("DATE_TRUNC('week', NOW()) + INTERVAL '2 weeks'")
    )
  end

  defp apply_specific_date_filter(query, :this_month) do
    Ash.Query.filter(
      query,
      starts_at > now() and starts_at <= fragment("NOW() + INTERVAL '30 days'")
    )
  end

  defp apply_type_filter(query) do
    case Ash.Query.get_argument(query, :type_filter) do
      nil -> query
      :any_type -> query
      :online -> Ash.Query.filter(query, event_type in [:virtual, :hybrid])
      :in_person -> Ash.Query.filter(query, event_type in [:in_person, :hybrid])
    end
  end

  defp apply_status_filter(query) do
    case Ash.Query.get_argument(query, :status_filter) do
      nil -> query
      :any_status -> query
      :upcoming -> Ash.Query.filter(query, starts_at > now())
      :in_progress -> Ash.Query.filter(query, starts_at <= now() and ends_at >= now())
      :completed -> Ash.Query.filter(query, ends_at < now())
      # Note: :draft and :cancelled would require actual status attribute
      # For now, we'll just return the query unchanged for these
      :draft -> query
      :cancelled -> query
    end
  end

  defp apply_sorting(query) do
    # Apply appropriate sorting based on date filter
    case Ash.Query.get_argument(query, :date_filter) do
      :past_events ->
        Ash.Query.sort(query, starts_at: :desc)

      _ ->
        Ash.Query.sort(query, starts_at: :asc)
    end
  end
end
