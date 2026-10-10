defmodule HuddlzWeb.AuthReturnTo do
  @moduledoc false
  alias Plug.Conn.Query

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
  Reconstructs the destination of a routed LiveView before its mount loads data.

  On connected navigation the connection URI is the websocket transport, not
  the requested page. The router supplies the path; mount params supply its
  path values and decoded query. Ambiguous or unsupported routes fail closed.
  """
  def for_live_view(
        %{
          router: router,
          view: view,
          assigns: %{live_action: action},
          host_uri: %URI{host: host}
        },
        params
      )
      when is_atom(router) and not is_nil(router) and is_map(params) do
    routes =
      Enum.filter(Phoenix.Router.routes(router), fn route ->
        route.plug == Phoenix.LiveView.Plug and route.plug_opts == action and
          match?({route_view, _, _} when route_view == view, route.metadata[:mfa])
      end)

    with [route] <- routes,
         {:ok, path, keys} <- route_path(route.path, params),
         %{route: pattern} <-
           Phoenix.Router.route_info(router, "GET", path, host),
         true <- pattern == route.path do
      query =
        params |> Map.drop(keys) |> Query.encode() |> URI.encode(&(&1 not in ~c"[]"))

      validate(if query == "", do: path, else: path <> "?" <> query)
    else
      _ -> nil
    end
  end

  def for_live_view(_socket, _params), do: nil

  defp route_path(pattern, params) do
    pattern
    |> String.split("/")
    |> Enum.reduce_while({:ok, [], []}, fn
      ":" <> key, {:ok, parts, keys} ->
        case params[key] do
          value when is_binary(value) ->
            {:cont, {:ok, [URI.encode(value, &URI.char_unreserved?/1) | parts], [key | keys]}}

          _ ->
            {:halt, :error}
        end

      "*" <> _, _ ->
        {:halt, :error}

      part, {:ok, parts, keys} ->
        {:cont, {:ok, [part | parts], keys}}
    end)
    |> case do
      {:ok, parts, keys} -> {:ok, parts |> Enum.reverse() |> Enum.join("/"), keys}
      :error -> :error
    end
  end

  defp local_path?(%URI{scheme: nil, host: nil, path: "/" <> _ = path}, _destination) do
    not String.starts_with?(path, "//") and
      not String.contains?(String.downcase(path), ["\\", "%2f", "%5c"])
  end

  defp local_path?(_uri, _path), do: false
end
