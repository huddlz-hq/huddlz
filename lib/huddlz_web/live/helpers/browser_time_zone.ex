defmodule HuddlzWeb.Live.Helpers.BrowserTimeZone do
  @moduledoc """
  Resolves the canonical time zone reported by a connected browser.
  """

  import Phoenix.LiveView, only: [connected?: 1, get_connect_params: 1]

  alias Huddlz.TimeZone

  def for_socket(socket) do
    time_zone = if connected?(socket), do: get_connect_params(socket)["timezone"]
    TimeZone.canonical_or_eastern(time_zone)
  end
end
