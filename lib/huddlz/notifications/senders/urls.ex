defmodule Huddlz.Notifications.Senders.Urls do
  @moduledoc """
  Shared URL builders for notification payloads. Falls back to a
  sensible browse-by destination when payload keys are missing so
  emails always link somewhere useful.
  """

  use HuddlzWeb, :verified_routes

  @spec group_url(map()) :: String.t()
  def group_url(%{"group_slug" => slug}) when is_binary(slug), do: url(~p"/groups/#{slug}")
  def group_url(_), do: url(~p"/discover?#{[scope: "groups"]}")
end
