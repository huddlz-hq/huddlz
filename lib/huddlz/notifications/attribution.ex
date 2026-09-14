defmodule Huddlz.Notifications.Attribution do
  @moduledoc """
  Resolves the people named in notification payloads at delivery and read time.
  A stored name is a snapshot, not permission to expose a suspended account.
  Older payloads without a person ID use "Someone": names are not identities.
  """

  alias Huddlz.Accounts.User
  alias Huddlz.Accounts.User.Preparations.NeutralizeSuspended

  require Ash.Query

  @people [
    {"rsvper_id", "rsvper_display_name"},
    {"joiner_id", "joiner_display_name"},
    {"inviter_id", "inviter_name"},
    {"previous_owner_id", "previous_owner_display_name"},
    {"new_owner_id", "new_owner_display_name"}
  ]

  def resolve(payload), do: resolve_many([payload]) |> hd()

  def resolve_many(payloads) do
    ids =
      for payload <- payloads,
          {id_key, _name_key} <- @people,
          id = payload[id_key],
          not is_nil(id),
          uniq: true,
          do: id

    people = suspension_statuses(ids)
    Enum.map(payloads, &resolve_people(&1, people))
  end

  defp suspension_statuses([]), do: %{}

  defp suspension_statuses(ids) do
    User
    |> Ash.Query.filter(id in ^ids)
    |> Ash.Query.select([:id, :suspended_at])
    |> Ash.read!(authorize?: false)
    |> Map.new(&{&1.id, User.suspended?(&1)})
  end

  defp resolve_people(payload, people) do
    Enum.reduce(@people, payload, fn {id_key, name_key}, payload ->
      if Map.has_key?(payload, name_key) do
        name = display_name(payload[name_key], Map.fetch(people, payload[id_key]))
        Map.put(payload, name_key, name)
      else
        payload
      end
    end)
  end

  defp display_name(_name, {:ok, true}), do: NeutralizeSuspended.label()
  defp display_name(name, {:ok, false}), do: name
  defp display_name(_name, :error), do: "Someone"
end
