defmodule Huddlz.Communities.Huddl.Preparations.ApplySearchFilters do
  @moduledoc """
  Applies search filters to huddl queries including text search, date filtering, and huddl-type filtering.
  """
  use Ash.Resource.Preparation
  require Ash.Query

  alias Huddlz.TimeZone

  @meters_per_mile 1609.344

  def prepare(query, _opts, context) do
    query
    |> apply_lifecycle_filter()
    |> apply_text_filter()
    |> apply_date_filter()
    |> apply_event_type_filter()
    |> apply_location_filter()
    |> apply_relationship_filter(context)
    |> apply_sort()
  end

  defp apply_lifecycle_filter(query) do
    case Ash.Query.get_argument(query, :relationship) do
      relationship when relationship in [:hosting, :attending, :waitlisted] ->
        Ash.Query.filter(query, lifecycle_state in [:published, :cancelled, :completed])

      _ ->
        Ash.Query.filter(query, lifecycle_state in [:published, :completed])
    end
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
    now = Ash.Query.get_argument(query, :now) || DateTime.utc_now()
    time_zone = Ash.Query.get_argument(query, :search_time_zone)

    if date_filter in [:this_week, :this_month] and not TimeZone.canonical?(time_zone) do
      Ash.Query.add_error(
        query,
        [:search_time_zone],
        "search time zone must be resolved for calendar-period filters"
      )
    else
      filter_by_date(query, date_filter, now, time_zone)
    end
  end

  # Include in-progress huddlz.
  defp filter_by_date(query, :upcoming, now, _time_zone),
    do: Ash.Query.filter(query, ends_at > ^now)

  defp filter_by_date(query, :this_week, now, time_zone) do
    {_week_start, week_end} = week_boundaries(now, time_zone)
    Ash.Query.filter(query, ends_at > ^now and starts_at <= ^week_end)
  end

  defp filter_by_date(query, :this_month, now, time_zone) do
    {_month_start, month_end} = month_boundaries(now, time_zone)
    Ash.Query.filter(query, ends_at > ^now and starts_at <= ^month_end)
  end

  defp filter_by_date(query, :past, now, _time_zone),
    do: Ash.Query.filter(query, ends_at < ^now)

  defp filter_by_date(query, _date_filter, _now, _time_zone), do: query

  defp week_boundaries(now, time_zone) do
    today = local_date(now, time_zone)
    sunday = Date.add(today, -rem(Date.day_of_week(today), 7))

    {utc_boundary(sunday, ~T[00:00:00], time_zone),
     utc_boundary(Date.add(sunday, 6), ~T[23:59:59], time_zone)}
  end

  defp month_boundaries(now, time_zone) do
    today = local_date(now, time_zone)
    first = Date.new!(today.year, today.month, 1)
    last = Date.end_of_month(first)
    {utc_boundary(first, ~T[00:00:00], time_zone), utc_boundary(last, ~T[23:59:59], time_zone)}
  end

  defp local_date(now, time_zone) do
    now |> DateTime.shift_zone!(time_zone) |> DateTime.to_date()
  end

  defp utc_boundary(date, time, time_zone) do
    date |> DateTime.new!(time, time_zone) |> DateTime.shift_zone!("Etc/UTC")
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
      distance_meters = distance_miles * @meters_per_mile

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

  defp apply_relationship_filter(query, %{actor: nil}) do
    # An anonymous actor cannot host or attend anything; force an empty result
    # rather than ignoring the relationship filter (which would silently broaden
    # the query and leak unrelated huddlz to API consumers).
    case Ash.Query.get_argument(query, :relationship) do
      relationship when relationship in [:hosting, :attending, :waitlisted] ->
        Ash.Query.filter(query, false)

      _ ->
        query
    end
  end

  defp apply_relationship_filter(query, %{actor: actor}) do
    case Ash.Query.get_argument(query, :relationship) do
      :hosting ->
        Ash.Query.filter(query, creator_id == ^actor.id)

      :attending ->
        Ash.Query.filter(
          query,
          exists(attendees, user_id == ^actor.id and is_nil(waitlisted_at))
        )

      :waitlisted ->
        Ash.Query.filter(
          query,
          exists(attendees, user_id == ^actor.id and not is_nil(waitlisted_at))
        )

      _ ->
        query
    end
  end

  defp apply_sort(query) do
    case Ash.Query.get_argument(query, :sort) do
      :newest -> Ash.Query.sort(query, inserted_at: :desc)
      _ -> Ash.Query.sort(query, starts_at: :asc)
    end
  end
end
