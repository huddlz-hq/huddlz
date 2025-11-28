defmodule Huddlz.Storage.S3 do
  @moduledoc """
  S3-compatible storage adapter for production (Tigris on Fly.io).
  Uses req_s3 for all S3 operations.
  """

  @behaviour Huddlz.Storage

  @impl true
  def put(path, content, content_type) do
    bucket = bucket_name()

    req =
      Req.new()
      |> ReqS3.attach()

    case Req.put(req,
           url: "s3://#{bucket}/#{path}",
           body: content,
           headers: [{"content-type", content_type}]
         ) do
      {:ok, %{status: status}} when status in 200..299 ->
        {:ok, path}

      {:ok, %{status: status, body: body}} ->
        {:error, "S3 upload failed with status #{status}: #{inspect(body)}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl true
  def delete(path) do
    bucket = bucket_name()

    req =
      Req.new()
      |> ReqS3.attach()

    case Req.delete(req, url: "s3://#{bucket}/#{path}") do
      {:ok, %{status: status}} when status in [200, 204, 404] ->
        # 404 means already deleted, which is fine
        :ok

      {:ok, %{status: status, body: body}} ->
        {:error, "S3 delete failed with status #{status}: #{inspect(body)}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl true
  def url(path) do
    bucket = bucket_name()
    endpoint = endpoint_host()

    "https://#{bucket}.#{endpoint}/#{path}"
  end

  @impl true
  def exists?(path) do
    bucket = bucket_name()

    req =
      Req.new()
      |> ReqS3.attach()

    case Req.head(req, url: "s3://#{bucket}/#{path}") do
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
end
