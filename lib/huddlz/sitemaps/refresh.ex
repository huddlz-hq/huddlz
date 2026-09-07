defmodule Huddlz.Sitemaps.Refresh do
  @moduledoc "Refreshes the durable public sitemap every fifteen minutes."
  use Oban.Worker, queue: :default, max_attempts: 3

  @impl true
  def perform(%Oban.Job{}) do
    case Huddlz.Sitemaps.refresh() do
      {:ok, :ok} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end
end
