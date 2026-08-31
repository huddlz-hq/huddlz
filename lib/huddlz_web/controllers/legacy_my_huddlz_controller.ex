defmodule HuddlzWeb.LegacyMyHuddlzController do
  use HuddlzWeb, :controller

  def show(conn, _params), do: redirect(conn, to: ~p"/calendar")
end
