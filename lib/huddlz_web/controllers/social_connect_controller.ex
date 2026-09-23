defmodule HuddlzWeb.SocialConnectController do
  @moduledoc """
  The hand-off that connects a place: the owner is sent to the platform's
  consent screen with a signed state naming the group, and the platform
  sends them back here with a code that becomes the connection. The Social
  tab then opens the new connection's schedule.
  """
  use HuddlzWeb, :controller

  alias Huddlz.Communities
  alias Huddlz.Communities.SocialConnection.Kind
  alias Huddlz.Social

  @salt "social connect"
  # Long enough to pick a channel, short enough that a stale link is useless.
  @state_max_age 15 * 60

  def connect(conn, %{"group_slug" => slug, "kind" => kind_param}) do
    user = conn.assigns[:current_user]

    with {:ok, kind} <- kind(kind_param),
         {:ok, group} <- owned_group(slug, user),
         :ok <- set_up(kind) do
      state = Phoenix.Token.sign(conn, @salt, {group.id, user.id, kind, nil})
      redirect(conn, external: Social.authorize_url(kind, state, callback_url(conn, kind)))
    else
      {:error, :not_set_up, kind} -> not_set_up(conn, kind, ~p"/organize/#{slug}/social")
      {:error, :not_owner} -> refuse(conn, ~p"/organize/#{slug}/social")
      {:error, _} -> refuse(conn, ~p"/organize")
    end
  end

  def reconnect(conn, %{"group_slug" => slug, "id" => id}) do
    user = conn.assigns[:current_user]

    with {:ok, group} <- owned_group(slug, user),
         {:ok, %{group_id: group_id} = connection} <-
           Communities.get_social_connection(id, actor: user),
         true <- group_id == group.id,
         :ok <- set_up(connection.kind) do
      state = Phoenix.Token.sign(conn, @salt, {group.id, user.id, connection.kind, connection.id})

      redirect(conn,
        external:
          Social.authorize_url(connection.kind, state, callback_url(conn, connection.kind))
      )
    else
      {:error, :not_set_up, kind} -> not_set_up(conn, kind, ~p"/organize/#{slug}/social")
      _ -> refuse(conn, ~p"/organize/#{slug}/social")
    end
  end

  def callback(conn, %{"kind" => kind_param, "code" => code, "state" => state}) do
    user = conn.assigns[:current_user]

    with {:ok, kind} <- kind(kind_param),
         {:ok, {group_id, user_id, ^kind, connection_id}} <-
           Phoenix.Token.verify(conn, @salt, state, max_age: @state_max_age),
         true <- not is_nil(user) and user.id == user_id,
         {:ok, group} <- owned_group_by_id(group_id, user),
         {:ok, place} <- Social.exchange(kind, code, callback_url(conn, kind)),
         {:ok, connection} <-
           save_connection(group, kind, connection_id, place, user) do
      conn
      |> put_flash(:info, "#{Communities.SocialConnection.place(connection)} is connected.")
      |> redirect(to: ~p"/organize/#{group.slug}/social?connected=#{connection.id}")
    else
      _ ->
        conn
        |> put_flash(:error, "That didn't connect. Try again from the Social tab.")
        |> redirect(to: ~p"/organize")
    end
  end

  # The platform sends the person back without a code when they cancel.
  def callback(conn, _params) do
    conn
    |> put_flash(:info, "Nothing was connected.")
    |> redirect(to: ~p"/organize")
  end

  defp save_connection(group, kind, nil, place, user) do
    Communities.connect_place(group.id, Map.put(place, :kind, kind), actor: user)
  end

  defp save_connection(%{id: group_id}, kind, id, place, user) do
    case Communities.get_social_connection(id, actor: user) do
      {:ok, %{group_id: ^group_id, kind: ^kind} = connection} ->
        Communities.reconnect_social_connection(connection, keep_names(place, kind), actor: user)

      _ ->
        {:error, :invalid_connection}
    end
  end

  # Discord's consent screen reports ids, not names, so the names the owner
  # gave the place stay through a reconnection.
  defp keep_names(place, :discord), do: Map.drop(place, [:workspace_name, :channel_name])
  defp keep_names(place, _kind), do: place

  defp kind(param) do
    case Social.kind_from_param(param) do
      nil -> {:error, :unknown_kind}
      kind -> {:ok, kind}
    end
  end

  defp owned_group(_slug, nil), do: {:error, :not_owner}

  defp owned_group(slug, user) do
    case Communities.get_group_for_organize(slug, actor: user) do
      {:ok, %{owner_id: owner_id} = group} when owner_id == user.id -> {:ok, group}
      {:ok, _group} -> {:error, :not_owner}
      {:error, _} = error -> error
    end
  end

  defp owned_group_by_id(group_id, user) do
    case Ash.get(Communities.Group, group_id, actor: user) do
      {:ok, %{owner_id: owner_id} = group} when owner_id == user.id -> {:ok, group}
      {:ok, _group} -> {:error, :not_owner}
      {:error, _} = error -> error
    end
  end

  # A platform without its app registered on this server has no consent
  # screen to send anyone to.
  defp set_up(kind) do
    if Social.configured?(kind), do: :ok, else: {:error, :not_set_up, kind}
  end

  defp not_set_up(conn, kind, to) do
    conn
    |> put_flash(
      :error,
      "#{Kind.label(kind)} isn't set up on this server yet."
    )
    |> redirect(to: to)
  end

  defp callback_url(conn, kind) do
    case Social.callback_origin() do
      nil -> url(conn, ~p"/social/#{kind}/callback")
      origin -> origin <> ~p"/social/#{kind}/callback"
    end
  end

  defp refuse(conn, to) do
    conn
    |> put_flash(:error, "Only the group owner can connect a place.")
    |> redirect(to: to)
  end
end
