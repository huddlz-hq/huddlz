defmodule HuddlzWeb.AuthReturnTo do
  @moduledoc false

  @doc """
  Returns a local path that is safe to use after authentication, or `nil`.
  """
  @spec validate(term()) :: String.t() | nil
  def validate(path) when is_binary(path) do
    case URI.new(path) do
      {:ok, uri} -> if local_path?(uri, path), do: path
      _ -> nil
    end
  end

  def validate(_path), do: nil

  @doc """
  The sign-in address that brings the person back to `destination` after
  signing in, or the bare sign-in address when `destination` is not a safe
  local path. Accepts a path or a request's `URI`.
  """
  @spec sign_in_path(URI.t() | String.t() | nil) :: String.t()
  def sign_in_path(%URI{path: path, query: query}) when query in [nil, ""], do: sign_in_path(path)

  def sign_in_path(%URI{path: path, query: query}) when is_binary(path),
    do: sign_in_path(path <> "?" <> query)

  def sign_in_path(%URI{}), do: "/sign-in"

  def sign_in_path(destination) do
    case validate(destination) do
      nil -> "/sign-in"
      return_to -> "/sign-in?" <> URI.encode_query(return_to: return_to)
    end
  end

  defp local_path?(%URI{scheme: nil, host: nil, path: "/" <> _}, path) do
    not String.starts_with?(path, "//") and
      not String.contains?(String.downcase(path), ["\\", "%2f", "%5c"])
  end

  defp local_path?(_uri, _path), do: false
end
