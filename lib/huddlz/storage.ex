defmodule Huddlz.Storage do
  @moduledoc """
  Storage behaviour and facade for file storage operations.
  Delegates to the configured adapter (local or S3).
  """

  @type path :: String.t()
  @type source_path :: String.t()
  @type storage_path :: String.t()
  @type content_type :: String.t()
  @type url :: String.t()

  @doc "Store a file from source_path to storage_path and return the storage path"
  @callback put(source_path, storage_path, content_type) :: {:ok, storage_path} | {:error, term()}

  @doc "Delete a file by its storage path"
  @callback delete(path) :: :ok | {:error, term()}

  @doc "Generate a public URL for the stored file"
  @callback url(path) :: url

  @doc "Check if a file exists at the given path"
  @callback exists?(path) :: boolean()

  @adapter Application.compile_env(:huddlz, [:storage, :adapter], Huddlz.Storage.S3)

  @doc """
  Store a file from source_path to storage_path.
  """
  def put(source_path, storage_path, content_type) do
    @adapter.put(source_path, storage_path, content_type)
  end

  @doc """
  Delete a file at the given path.
  """
  def delete(path), do: @adapter.delete(path)

  @doc """
  Get the public URL for a file.
  """
  def url(path), do: @adapter.url(path)

  @doc """
  Check if a file exists.
  """
  def exists?(path), do: @adapter.exists?(path)
end
