defmodule Huddlz.Storage.S3 do
  @moduledoc """
  S3-compatible storage adapter for production (Tigris on Fly.io).
  Uses req_s3 for all S3 operations.
  """

  require Logger

  @behaviour Huddlz.Storage

  @impl true
  def put(source_path, storage_path, content_type) do
    bucket = bucket_name()
    key = normalize_key(storage_path)
    req = Req.new() |> ReqS3.attach()

    with {:ok, content} <- File.read(source_path),
         {:ok, %{status: status}} when status in 200..299 <-
           Req.put(req,
             url: "s3://#{bucket}/#{key}",
             body: content,
             headers: [{"content-type", content_type}]
           ) do
      {:ok, storage_path}
    else
      {:ok, %{status: status, body: body}} ->
        Logger.error("S3 upload failed: status=#{status} key=#{key} body=#{inspect(body)}")
        {:error, "Storage upload failed"}

      {:error, reason} ->
        Logger.error("S3 upload error: key=#{key} reason=#{inspect(reason)}")
        {:error, "Storage upload failed"}
    end
  end

  @impl true
  def delete(path) do
    bucket = bucket_name()
    key = normalize_key(path)

    req =
      Req.new()
      |> ReqS3.attach()

    case Req.delete(req, url: "s3://#{bucket}/#{key}") do
      {:ok, %{status: status}} when status in [200, 204, 404] ->
        # 404 means already deleted, which is fine
        :ok

      {:ok, %{status: status, body: body}} ->
        Logger.error("S3 delete failed: status=#{status} key=#{key} body=#{inspect(body)}")

        {:error, "Storage delete failed"}

      {:error, reason} ->
        Logger.error("S3 delete error: key=#{key} reason=#{inspect(reason)}")
        {:error, "Storage delete failed"}
    end
  end

  @impl true
  def url(path) do
    bucket = bucket_name()
    endpoint = endpoint_host()
    key = normalize_key(path)

    "https://#{bucket}.#{endpoint}/#{key}"
  end

  @impl true
  def exists?(path) do
    bucket = bucket_name()
    key = normalize_key(path)

    req =
      Req.new()
      |> ReqS3.attach()

    case Req.head(req, url: "s3://#{bucket}/#{key}") do
      {:ok, %{status: 200}} -> true
      _ -> false
    end
  end

  defp bucket_name do
    Application.get_env(:huddlz, :storage)[:bucket] ||
      raise "Missing :bucket configuration for S3 storage"
  end

  defp endpoint_host do
    endpoint = Application.get_env(:huddlz, :storage)[:endpoint]

    if endpoint do
      endpoint
      |> String.replace_prefix("https://", "")
      |> String.replace_prefix("http://", "")
    else
      "fly.storage.tigris.dev"
    end
  end

  # Normalize path to S3 key format (no leading slash)
  defp normalize_key(path) do
    path
    |> String.trim_leading("/")
  end
end
