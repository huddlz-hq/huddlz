defmodule HuddlzWeb.HealthController do
  @moduledoc """
  Reports whether this Machine is ready to receive traffic.
  """

  use HuddlzWeb, :controller

  def show(conn, _params) do
    case Huddlz.Health.check() do
      :ok -> send_health(conn, 200, "ok")
      :error -> send_health(conn, 503, "unavailable")
    end
  end

  defp send_health(conn, status, body) do
    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(status, body)
  end
end
