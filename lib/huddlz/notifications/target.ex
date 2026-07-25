defmodule Huddlz.Notifications.Target do
  @moduledoc """
  Resolves an in-app notification's destination against current data and
  authorization.

  Notification copy is historical, but destinations are live: a referenced
  group or huddl may have been removed, or the recipient may no longer be
  allowed to see it. This module keeps that distinction explicit and only
  returns canonical paths rebuilt from records the current actor can read.
  """

  alias Huddlz.Accounts.User
  alias Huddlz.Communities
  alias Huddlz.Notifications.Notification

  @type resolution :: {:available, String.t()} | :resolved | :none

  @spec resolve(Notification.t(), User.t()) :: resolution()
  def resolve(%Notification{source_url: nil}, %User{}), do: :none

  def resolve(
        %Notification{payload: %{"huddl_id" => huddl_id, "group_slug" => group_slug}},
        %User{} = user
      )
      when is_binary(huddl_id) and is_binary(group_slug) do
    case Communities.get_huddl(huddl_id, actor: user, load: [:group]) do
      {:ok, %{group: %{slug: ^group_slug}} = huddl} ->
        {:available, "/groups/#{group_slug}/huddlz/#{huddl.id}"}

      _ ->
        :resolved
    end
  end

  def resolve(
        %Notification{payload: %{"group_slug" => group_slug}},
        %User{} = user
      )
      when is_binary(group_slug) do
    case Communities.get_by_slug(group_slug, actor: user) do
      {:ok, %{slug: ^group_slug}} -> {:available, "/groups/#{group_slug}"}
      _ -> :resolved
    end
  end

  def resolve(%Notification{source_url: source_url}, %User{})
      when source_url in ["/profile", "/profile/notifications", "/notifications"] do
    {:available, source_url}
  end

  def resolve(%Notification{}, %User{}), do: :resolved
end
