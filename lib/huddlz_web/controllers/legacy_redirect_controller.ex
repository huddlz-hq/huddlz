defmodule HuddlzWeb.LegacyRedirectController do
  @moduledoc """
  Permanent redirects for legacy URLs that have moved to dedicated routes.

  The old `/me` dashboard split into `/my-huddlz`, `/my-groups`, and
  `/notifications` during the v3 migration. These redirects keep inbound
  links working from emails, bookmarks, and external sites.
  """
  use HuddlzWeb, :controller

  def me(conn, %{"tab" => "groups"}), do: redirect(conn, to: ~p"/my-groups")
  def me(conn, %{"tab" => "updates"}), do: redirect(conn, to: ~p"/notifications")

  def me(conn, %{"tab" => "invites"}),
    do: redirect(conn, to: ~p"/notifications?#{[filter: :invites]}")

  def me(conn, _params), do: redirect(conn, to: ~p"/my-huddlz")
end
