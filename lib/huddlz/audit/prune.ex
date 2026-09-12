defmodule Huddlz.Audit.Prune do
  @moduledoc "Prunes expired troubleshooting history daily."
  use Oban.Worker, queue: :default, max_attempts: 3

  @impl true
  def perform(%Oban.Job{}), do: Huddlz.Audit.prune()
end
