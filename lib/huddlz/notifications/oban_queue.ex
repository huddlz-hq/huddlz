defmodule Huddlz.Notifications.ObanQueue do
  @moduledoc false

  @behaviour Huddlz.Notifications.Queue

  alias Huddlz.Notifications.DeliverWorker

  @impl true
  def enqueue(args) do
    args
    |> DeliverWorker.new()
    |> Oban.insert()
  end
end
