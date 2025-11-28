defmodule Huddlz.Storage.Local do
  @moduledoc """
  Local filesystem storage adapter for development and testing.
  Stores files in priv/static/ and serves via Plug.Static.

  Paths are expected to start with /uploads/ (e.g., /uploads/profile_pictures/...)
  """

  @behaviour Huddlz.Storage

  @impl true
  def put(source_path, storage_path, _content_type) do
    full_path = full_path(storage_path)

    # Ensure directory exists
    full_path |> Path.dirname() |> File.mkdir_p!()

    case File.cp(source_path, full_path) do
      :ok -> {:ok, storage_path}
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def delete(storage_path) do
    full_path = full_path(storage_path)

    case File.rm(full_path) do
      :ok -> :ok
      # File already gone, consider success
      {:error, :enoent} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def url(storage_path) do
    # Storage path already includes /uploads/ prefix
    storage_path
  end

  @impl true
  def exists?(storage_path) do
    full_path(storage_path) |> File.exists?()
  end

  defp full_path(storage_path) do
    # Storage paths are like /uploads/profile_pictures/...
    # We store them in priv/static/uploads/... so we join with priv/static
    Path.join("priv/static", storage_path)
  end
end
