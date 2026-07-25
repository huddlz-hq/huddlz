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

  defp local_path?(%URI{scheme: nil, host: nil, path: "/" <> _}, path) do
    not String.starts_with?(path, "//") and
      not String.contains?(String.downcase(path), ["\\", "%2f", "%5c"])
  end

  defp local_path?(_uri, _path), do: false
end
