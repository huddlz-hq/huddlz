defmodule Huddlz.Communities.Huddl.Changes.Rsvp do
  @moduledoc """
  Handles RSVP logic: creates an attendee record if one doesn't already exist.
  The rsvp_count is computed as an aggregate, so no manual counter management is needed.
  """
  use Ash.Resource.Change

  alias Ecto.Adapters.SQL
  alias Huddlz.Communities.HuddlAttendee
  alias Huddlz.Repo

  require Ash.Query

  def change(changeset, _opts, %{actor: %{id: user_id}}) when not is_nil(user_id) do
    huddl_id = changeset.data.id

    case reserve_spot(huddl_id, user_id) do
      :ok ->
        changeset

      {:error, error} ->
        Ash.Changeset.add_error(changeset, error)
    end
  end

  def change(changeset, _opts, _context) do
    Ash.Changeset.add_error(changeset, "An actor is required to RSVP")
  end

  defp reserve_spot(huddl_id, user_id) do
    dumped_huddl_id = Ecto.UUID.dump!(huddl_id)

    Repo.transaction(fn ->
      lock_huddl!(dumped_huddl_id)

      reserve_if_available!(dumped_huddl_id, huddl_id, user_id)
    end)
    |> case do
      {:ok, :ok} -> :ok
      {:error, error} -> {:error, error}
    end
  end

  defp reserve_if_available!(dumped_huddl_id, huddl_id, user_id) do
    if existing_rsvp?(huddl_id, user_id) do
      :ok
    else
      create_rsvp_if_capacity_available!(dumped_huddl_id, huddl_id, user_id)
    end
  end

  defp create_rsvp_if_capacity_available!(dumped_huddl_id, huddl_id, user_id) do
    max_attendees = max_attendees!(dumped_huddl_id)
    rsvp_count = rsvp_count!(dumped_huddl_id)

    if max_attendees && rsvp_count >= max_attendees do
      Repo.rollback("This huddl is full")
    else
      create_rsvp!(huddl_id, user_id)
      :ok
    end
  end

  defp lock_huddl!(huddl_id) do
    SQL.query!(
      Repo,
      "SELECT id FROM huddlz WHERE id = $1 FOR UPDATE",
      [huddl_id]
    )
  end

  defp existing_rsvp?(huddl_id, user_id) do
    case HuddlAttendee
         |> Ash.Query.for_read(:check_rsvp, %{huddl_id: huddl_id}, actor: %{id: user_id})
         |> Ash.read_one(authorize?: false) do
      {:ok, nil} -> false
      {:ok, _} -> true
      {:error, error} -> Repo.rollback(error)
    end
  end

  defp max_attendees!(huddl_id) do
    %{rows: [[max_attendees]]} =
      SQL.query!(Repo, "SELECT max_attendees FROM huddlz WHERE id = $1", [huddl_id])

    max_attendees
  end

  defp rsvp_count!(huddl_id) do
    %{rows: [[count]]} =
      SQL.query!(Repo, "SELECT count(*) FROM huddl_attendees WHERE huddl_id = $1", [huddl_id])

    count
  end

  defp create_rsvp!(huddl_id, user_id) do
    HuddlAttendee
    |> Ash.Changeset.for_create(:rsvp, %{huddl_id: huddl_id, user_id: user_id})
    |> Ash.create!(authorize?: false)
  end
end
