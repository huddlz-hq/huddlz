defmodule Huddlz.Communities.WaitlistPromotion do
  @moduledoc """
  Fills available seats from the huddl's ordered waitlist inside the calling
  action's transaction. Only people whose RSVP changes receive a promotion notice.
  """

  alias Huddlz.Accounts.User
  alias Huddlz.Communities
  alias Huddlz.Communities.Huddl
  alias Huddlz.Notifications

  @doc "Fill at most one seat using the capacity read under the huddl lock after release."
  @spec fill_released_seat(Huddl.t(), keyword()) :: [Ecto.UUID.t()]
  def fill_released_seat(%Huddl{at_capacity: true}, _opts), do: []
  def fill_released_seat(%Huddl{at_capacity: false} = huddl, opts), do: promote(huddl, 1, opts)

  @doc "Fill the seats available under the new capacity. Lifting the cap admits everyone waiting."
  @spec fill_open_seats(Huddl.t(), keyword()) :: [Ecto.UUID.t()]
  def fill_open_seats(%Huddl{max_attendees: nil} = huddl, opts), do: promote(huddl, nil, opts)

  def fill_open_seats(%Huddl{max_attendees: capacity, rsvp_count: count} = huddl, opts) do
    promote(huddl, max(capacity - count, 0), opts)
  end

  defp promote(_huddl, 0, _opts), do: []

  defp promote(huddl, limit, opts) do
    huddl.id
    |> Communities.list_huddl_waitlist!(authorize?: false, query: [limit: limit])
    |> Enum.map(fn attendee ->
      attendee
      |> Ash.Changeset.for_update(:promote_from_waitlist, %{}, opts)
      |> Ash.Changeset.set_context(%{paper_trail_metadata: %{automatic?: true}})
      |> Ash.update!(authorize?: false)

      attendee.user_id
    end)
  end

  @doc "Deliver the spot notification to each newly promoted person."
  @spec notify(Huddl.t(), [Ecto.UUID.t()]) :: :ok
  def notify(_huddl, []), do: :ok

  def notify(huddl, user_ids) do
    huddl = Ash.load!(huddl, :group, authorize?: false)

    payload = %{
      "huddl_id" => huddl.id,
      "huddl_title" => to_string(huddl.title),
      "group_name" => to_string(huddl.group.name),
      "group_slug" => to_string(huddl.group.slug),
      "starts_at_iso" => DateTime.to_iso8601(huddl.starts_at),
      "time_zone" => huddl.time_zone
    }

    Enum.each(user_ids, fn user_id ->
      with {:ok, user} <- Ash.get(User, user_id, authorize?: false) do
        Notifications.deliver(user, :waitlist_promoted, payload)
      end
    end)
  end
end
