defmodule Huddlz.Test.Storage do
  @moduledoc """
  Stores test files locally while allowing serial scenarios to exercise remote URLs.
  """
  @behaviour Huddlz.Storage

  @impl true
  defdelegate put(source, destination, content_type), to: Huddlz.Storage.Local

  @impl true
  defdelegate copy(source, destination, content_type), to: Huddlz.Storage.Local

  @impl true
  defdelegate delete(path), to: Huddlz.Storage.Local

  @impl true
  defdelegate exists?(path), to: Huddlz.Storage.Local

  @impl true
  def url(path) do
    adapter = Application.get_env(:huddlz, :storage)[:url_adapter] || Huddlz.Storage.Local
    adapter.url(path)
  end
end
