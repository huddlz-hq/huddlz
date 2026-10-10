defmodule HuddlzWeb.AuthReturnTo do
  @moduledoc false
  alias Plug.Conn.Query

  @doc """
  Returns a local path that is safe to use after authentication, or `nil`.
  """
  @spec validate(term()) :: String.t() | nil
  def validate(path) when is_binary(path) do
    case URI.new(path) do
      {:ok, uri} -> if local_path?(uri), do: path
      _ -> nil
    end
  end

  def validate(_path), do: nil

  @doc """
  Returns the safe local path and query of a requested URI, or `nil`.
  """
  def from_uri(uri) do
    %URI{path: path, query: query} = URI.parse(uri)
    validate(if query, do: "#{path}?#{query}", else: path)
  end

  @doc """
  Rebuilds the page a routed LiveView is mounting, before it loads any data.
  A mount sees params, not its URI, so the router's path pattern is filled
  back in from them and the remaining params become the query.
  """
  def for_live_view(%{router: router, view: view, assigns: %{live_action: action}}, params)
      when is_atom(router) and not is_nil(router) and is_map(params) do
    patterns =
      for %{path: path, metadata: %{phoenix_live_view: {^view, ^action, _, _}}} <-
            Phoenix.Router.routes(router),
          do: path

    with [pattern] <- patterns, false <- String.contains?(pattern, "*") do
      {segments, keys} =
        pattern
        |> String.split("/")
        |> Enum.map_reduce([], fn
          ":" <> key, keys -> {URI.encode(params[key], &URI.char_unreserved?/1), [key | keys]}
          segment, keys -> {segment, keys}
        end)

      path = Enum.join(segments, "/")

      query =
        params |> Map.drop(keys) |> Query.encode() |> URI.encode(&(&1 not in ~c"[]"))

      validate(if query == "", do: path, else: "#{path}?#{query}")
    else
      _ -> nil
    end
  end

  def for_live_view(_socket, _params), do: nil

  @doc """
  Adds a safe `return_to` to an authentication page's path. Unsafe or missing
  destinations leave the path bare.
  """
  def path(path, return_to) do
    case validate(return_to) do
      nil -> path
      return_to -> path <> "?" <> URI.encode_query(return_to: return_to)
    end
  end

  defp local_path?(%URI{scheme: nil, host: nil, path: "/" <> _ = path}) do
    not String.starts_with?(path, "//") and
      not String.contains?(String.downcase(path), ["\\", "%2f", "%5c"])
  end

  defp local_path?(_uri), do: false
end
