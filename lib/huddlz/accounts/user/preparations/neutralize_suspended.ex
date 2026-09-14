defmodule Huddlz.Accounts.User.Preparations.NeutralizeSuspended do
  @moduledoc """
  Reads a suspended person as "Suspended account" for everyone but an
  administrator, so records that must keep their author (a huddl's creator,
  an activity feed line, a past attendance, an API relationship) never
  carry the name or picture that got the account suspended.

  Applied to every read of `Huddlz.Accounts.User`, including relationship
  loads from other resources. Administrators, who review suspensions, and
  the person themselves read the stored values.
  """

  use Ash.Resource.Preparation

  alias Huddlz.Accounts.User

  @label "Suspended account"

  @doc "The name a suspended person is shown as."
  def label, do: @label

  @impl true
  def prepare(query, _opts, %{actor: actor}) do
    if User.admin?(actor) do
      query
    else
      Ash.Query.after_action(query, fn _query, records ->
        {:ok, Enum.map(records, &neutralize(&1, actor))}
      end)
    end
  end

  defp neutralize(%User{suspended_at: %DateTime{}} = user, actor) do
    if self?(user, actor) do
      user
    else
      user
      |> Map.put(:display_name, @label)
      |> put_if_loaded(:current_profile_picture_url, nil)
      |> put_if_loaded(:home_location, nil)
    end
  end

  defp neutralize(record, _actor), do: record

  defp self?(%User{id: id}, %{id: id}), do: true
  defp self?(_user, _actor), do: false

  defp put_if_loaded(user, key, value) do
    case Map.get(user, key) do
      %Ash.NotLoaded{} -> user
      _loaded -> Map.put(user, key, value)
    end
  end
end
