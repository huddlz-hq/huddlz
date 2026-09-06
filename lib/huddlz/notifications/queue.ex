defmodule Huddlz.Notifications.Queue do
  @moduledoc """
  Boundary for enqueueing asynchronous notification delivery.
  """

  @callback enqueue(map()) :: {:ok, Oban.Job.t()} | {:error, term()}
end
