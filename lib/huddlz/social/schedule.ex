defmodule Huddlz.Social.Schedule do
  @moduledoc """
  When each moment of a social schedule falls for a huddl, and the planned
  posts that follow from it. Planning is repeatable: it moves posts that
  have not gone out to the huddl's current time, drops the ones the
  schedule no longer wants, and never touches a post that has gone out.

  A moment that has already passed, or that would fall once the huddl has
  started, is skipped rather than planned late. Only a published public
  huddl of a public group is planned for.
  """

  require Ash.Query

  alias Huddlz.Communities.{Huddl, SocialConnection, SocialPost}
  alias Huddlz.Communities.SocialPost.Occasion
  alias Huddlz.TimeZone

  @timed [:week_before, :day_before, :morning_of, :hour_before]
  @morning ~T[09:00:00]

  @doc "The moments planned ahead of a huddl; \"when published\" is sent as it happens."
  def timed_moments, do: @timed

  @doc """
  When a moment falls for a huddl: a week or a day before at the huddl's own
  time of day, 9:00 in its time zone on the day, or an hour before it
  starts. Nil when the local time does not exist (a daylight saving gap).
  """
  @spec due_at(atom(), map()) :: DateTime.t() | nil
  def due_at(:hour_before, huddl), do: DateTime.add(huddl.starts_at, -1, :hour)
  def due_at(:week_before, huddl), do: shift_local(huddl, -7, local_time(huddl))
  def due_at(:day_before, huddl), do: shift_local(huddl, -1, local_time(huddl))
  def due_at(:morning_of, huddl), do: shift_local(huddl, 0, @morning)

  defp local(huddl), do: DateTime.shift_zone!(huddl.starts_at, huddl.time_zone)
  defp local_time(huddl), do: huddl |> local() |> DateTime.to_time()

  defp shift_local(huddl, days, time) do
    date = huddl |> local() |> DateTime.to_date() |> Date.add(days)

    case TimeZone.resolve_local(date, time, huddl.time_zone) do
      {:ok, datetime} -> datetime |> DateTime.shift_zone!("Etc/UTC") |> DateTime.truncate(:second)
      {:error, _} -> nil
    end
  end

  @doc """
  Plan a huddl's timed posts on every connection of its group, or drop its
  planned posts if it can no longer be posted.
  """
  @spec plan_huddl(Huddl.t()) :: :ok
  def plan_huddl(%Huddl{} = huddl) do
    huddl = Ash.load!(huddl, [:group], authorize?: false)
    connections = connections_of(huddl.group_id)

    if postable?(huddl) do
      Enum.each(connections, &plan(&1, huddl))
    else
      drop_planned(huddl_id: huddl.id)
    end
  end

  @doc """
  Post a huddl that has just gone public, straight away, on every
  connection that posts when a huddl is published: as itself, or as the
  first huddl of a new series (`:series`).
  """
  @spec announce(Huddl.t(), :when_published | :series) :: :ok
  def announce(%Huddl{} = huddl, occasion) when occasion in [:when_published, :series] do
    huddl = Ash.load!(huddl, [:group], authorize?: false)
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    if postable?(huddl) do
      huddl.group_id
      |> connections_of()
      |> Enum.filter(&(:when_published in &1.moments))
      |> Enum.each(&schedule!(&1, huddl, occasion, now))
    end

    :ok
  end

  @doc "Plan a connection's timed posts for every upcoming huddl of its group."
  @spec plan_connection(SocialConnection.t()) :: :ok
  def plan_connection(%SocialConnection{} = connection) do
    Huddl
    |> Ash.Query.filter(
      group_id == ^connection.group_id and lifecycle_state == :published and
        is_private == false and starts_at > now()
    )
    |> Ash.Query.load(:group)
    |> Ash.read!(authorize?: false)
    |> Enum.filter(&postable?/1)
    |> Enum.each(&plan(connection, &1))
  end

  @doc "Whether a huddl may be posted at all: published, public, in a public group."
  def postable?(%Huddl{
        lifecycle_state: :published,
        is_private: false,
        group: %{is_public: true}
      }),
      do: true

  def postable?(_huddl), do: false

  defp plan(connection, huddl) do
    now = DateTime.utc_now()

    Enum.each(@timed, fn moment ->
      due = moment in connection.moments && due_at(moment, huddl)

      if due && DateTime.after?(due, now) && DateTime.before?(due, huddl.starts_at) do
        schedule!(connection, huddl, moment, due)
      else
        drop_planned(social_connection_id: connection.id, huddl_id: huddl.id, occasion: moment)
      end
    end)
  end

  defp schedule!(connection, huddl, occasion, due) do
    SocialPost
    |> Ash.Changeset.for_create(:schedule, %{
      social_connection_id: connection.id,
      huddl_id: huddl.id,
      occasion: occasion,
      due_at: due
    })
    |> Ash.create!(authorize?: false)
  end

  # Drops posts that have not gone out. Follow-ups are left alone: they say
  # something that already happened.
  defp drop_planned(filters) do
    follow_ups = Occasion.follow_ups()

    SocialPost
    |> Ash.Query.do_filter(filters)
    |> Ash.Query.filter(state == :scheduled and occasion not in ^follow_ups)
    |> Ash.bulk_destroy!(:drop, %{}, authorize?: false, strategy: [:atomic, :stream])

    :ok
  end

  defp connections_of(group_id) do
    SocialConnection
    |> Ash.Query.filter(group_id == ^group_id)
    |> Ash.read!(authorize?: false)
  end
end
