defmodule HuddlzWeb.LegacyController do
  @moduledoc """
  Destinations that moved. Bookmarks and shared links to the old address
  land where the page went.
  """
  use HuddlzWeb, :controller

  # The huddlz feed was retired for the agenda (#539).
  def huddlz(conn, _params), do: redirect(conn, to: ~p"/agenda")
end
