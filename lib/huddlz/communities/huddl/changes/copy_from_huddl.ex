defmodule Huddlz.Communities.Huddl.Changes.CopyFromHuddl do
  @moduledoc """
  Fills a new huddl from the huddl named by `copied_from_id`.

  Anything the caller leaves out comes from the source: its details, location,
  capacity, visibility, local start time and duration, and a copy of its cover.
  The date is always the caller's. RSVPs, photos, turnout, lifecycle and the
  series stay with the source; the copy shares nothing with it afterwards, and
  only its audit history records where it came from.

  Runs first in `:create` so the copied values feed the location, time zone
  and schedule changes that follow.
  """

  use Ash.Resource.Change

  alias Huddlz.Communities.Huddl
  alias Huddlz.Communities.Huddl.CoverCopy

  @copied_attributes [
    :title,
    :description,
    :event_type,
    :group_location_id,
    :virtual_link,
    :is_private,
    :thumbnail_url,
    :max_attendees
  ]

  @impl true
  def change(changeset, _opts, context) do
    case Ash.Changeset.get_argument(changeset, :copied_from_id) do
      nil -> changeset
      source_id -> copy_from(changeset, source_id, context.actor)
    end
  end

  defp copy_from(changeset, source_id, actor) do
    case fetch_source(source_id, actor) do
      {:ok, source} ->
        changeset
        |> put_group(source)
        |> put_copied_attributes(source)
        |> require_location(source)
        |> put_schedule(source)
        |> copy_cover(source)
        |> record_source(source)

      :error ->
        Ash.Changeset.add_error(changeset,
          field: :copied_from_id,
          message: "could not be found"
        )
    end
  end

  # The actor must be able to see the source; the copy's own create policy
  # then decides whether they may organize huddlz in its group.
  defp fetch_source(source_id, actor) do
    with {:ok, %Huddl{}} <- Ash.get(Huddl, source_id, actor: actor),
         {:ok, %Huddl{} = source} <- Ash.get(Huddl, source_id, authorize?: false) do
      {:ok, source}
    else
      _missing -> :error
    end
  end

  defp put_group(changeset, source) do
    if supplied?(changeset, :group_id) and
         Ash.Changeset.get_attribute(changeset, :group_id) != source.group_id do
      Ash.Changeset.add_error(changeset,
        field: :group_id,
        message: "must be the copied huddl's group"
      )
    else
      Ash.Changeset.change_attribute(changeset, :group_id, source.group_id)
    end
  end

  defp put_copied_attributes(changeset, source) do
    Enum.reduce(@copied_attributes, changeset, fn attribute, changeset ->
      if supplied?(changeset, attribute) do
        changeset
      else
        Ash.Changeset.change_attribute(changeset, attribute, Map.get(source, attribute))
      end
    end)
  end

  # Attribute defaults count as changes on create; only the caller's own
  # values should win over the source's.
  defp supplied?(changeset, attribute) do
    Ash.Changeset.changing_attribute?(changeset, attribute) and
      attribute not in changeset.defaults
  end

  # A deleted address book location leaves the source without one. The copy
  # must not quietly lose its place, so the caller has to choose a new one.
  defp require_location(changeset, source) do
    physical? = Ash.Changeset.get_attribute(changeset, :event_type) in [:in_person, :hybrid]

    if physical? and is_nil(Ash.Changeset.get_attribute(changeset, :group_location_id)) and
         source.event_type in [:in_person, :hybrid] do
      Ash.Changeset.add_error(changeset,
        field: :group_location_id,
        message:
          "#{removed_location_name(source)} was removed from the address book; choose a location"
      )
    else
      changeset
    end
  end

  defp removed_location_name(%{physical_location: address})
       when is_binary(address) and address != "",
       do: address

  defp removed_location_name(_source), do: "The copied huddl's location"

  defp put_schedule(changeset, source) do
    changeset
    |> require_date()
    |> default_argument(:start_time, :starts_at, fn -> local_start_time(source) end)
    |> default_argument(:duration_minutes, :ends_at, fn ->
      DateTime.diff(source.ends_at, source.starts_at, :minute)
    end)
  end

  defp require_date(changeset) do
    if is_nil(Ash.Changeset.get_argument(changeset, :date)) and
         not supplied?(changeset, :starts_at) do
      Ash.Changeset.add_error(changeset,
        field: :date,
        message: "is required when copying a huddl"
      )
    else
      changeset
    end
  end

  defp default_argument(changeset, argument, attribute, value) do
    if is_nil(Ash.Changeset.get_argument(changeset, argument)) and
         not supplied?(changeset, attribute) do
      Ash.Changeset.set_argument(changeset, argument, value.())
    else
      changeset
    end
  end

  defp local_start_time(source) do
    source.starts_at
    |> DateTime.shift_zone!(source.time_zone)
    |> DateTime.to_time()
  end

  defp copy_cover(changeset, source) do
    if Ash.Changeset.get_argument(changeset, :pending_image_id) do
      changeset
    else
      Ash.Changeset.after_action(changeset, &copy_cover_to(&1, &2, source))
    end
  end

  defp copy_cover_to(changeset, huddl, source) do
    case CoverCopy.copy_current(source.id, huddl.id, cover_opts(changeset)) do
      :ok -> {:ok, huddl}
      {:error, error} -> {:error, error}
    end
  end

  # The source is recorded on the huddl's own history, not its cover's.
  defp cover_opts(changeset) do
    changeset
    |> Huddlz.Audit.nested_opts()
    |> update_in([:context, :paper_trail_metadata], &Map.delete(&1, :copied_from_id))
  end

  defp record_source(changeset, source) do
    metadata =
      Map.put(changeset.context[:paper_trail_metadata] || %{}, :copied_from_id, source.id)

    Ash.Changeset.put_context(changeset, :paper_trail_metadata, metadata)
  end
end
