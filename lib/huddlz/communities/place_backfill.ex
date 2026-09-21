defmodule Huddlz.Communities.PlaceBackfill do
  @moduledoc """
  Resolves saved locations that predate place ids to a full street address and
  Google place id, by reverse geocoding their stored coordinates.

  Older saved locations kept only the autocomplete label (often just a street
  and city), which map searches cannot pin to one place. Each resolved location
  gets its full address and place id, and the upcoming and past huddlz saved
  from it get the place id so their map links open the exact place.

  Locations Google cannot resolve to a street address are left untouched; their
  map links fall back to coordinates.
  """

  alias Huddlz.Communities.GroupLocation
  alias Huddlz.Geocoding
  alias Huddlz.Repo

  require Ash.Query

  @type summary :: %{resolved: non_neg_integer(), skipped: non_neg_integer()}

  @doc """
  Backfills every saved location without a place id.

  With `dry_run: true` nothing is written; the summary still reports what would
  be resolved. Returns `%{resolved: n, skipped: n}`.
  """
  @spec run(keyword()) :: summary()
  def run(opts \\ []) do
    dry_run? = Keyword.get(opts, :dry_run, false)

    GroupLocation
    |> Ash.Query.filter(is_nil(place_id))
    |> Ash.read!(authorize?: false)
    |> Enum.reduce(%{resolved: 0, skipped: 0}, fn location, summary ->
      case resolve(location, dry_run?) do
        :resolved -> Map.update!(summary, :resolved, &(&1 + 1))
        :skipped -> Map.update!(summary, :skipped, &(&1 + 1))
      end
    end)
  end

  defp resolve(location, dry_run?) do
    case Geocoding.reverse_geocode(location.latitude, location.longitude) do
      {:ok, %{formatted_address: address, place_id: place_id}} ->
        unless dry_run?, do: apply_resolution(location, address, place_id)
        :resolved

      {:error, _reason} ->
        :skipped
    end
  end

  defp apply_resolution(location, address, place_id) do
    location
    |> Ash.Changeset.for_update(:resolve_place, %{address: address, place_id: place_id},
      authorize?: false
    )
    |> Ash.update!()

    Repo.query!(
      "UPDATE huddlz SET place_id = $1 WHERE group_location_id = $2 AND place_id IS NULL",
      [place_id, Ecto.UUID.dump!(location.id)]
    )
  end
end
