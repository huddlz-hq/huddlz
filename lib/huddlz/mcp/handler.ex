defmodule Huddlz.MCP.Handler do
  @moduledoc """
  MCP protocol handler that binds one authenticated actor to each MCP session.
  """

  @behaviour MCP.Server.Handler

  alias Huddlz.MCP.Tools

  @impl MCP.Server.Handler
  def init(opts), do: {:ok, %{actor: Keyword.get(opts, :actor)}}

  @impl MCP.Server.Handler
  def handle_list_tools(_cursor, state), do: {:ok, Tools.definitions(), nil, state}

  @impl MCP.Server.Handler
  def handle_call_tool(name, arguments, state) do
    case Tools.call(name, arguments, state.actor) do
      {:ok, result} ->
        {:ok, [text_content(result)], state}

      {:error, :tool_not_found, message} ->
        {:error, -32_601, message, state}

      {:error, :invalid_params, message} ->
        {:error, -32_602, message, state}

      {:error, kind, message} when kind in [:authentication_required, :forbidden, :not_found] ->
        {:ok, [text_content(%{error: Atom.to_string(kind), message: message})], true, state}

      {:error, :internal, _message} ->
        {:ok, [text_content(%{error: "internal", message: "The request could not be completed"})],
         true, state}
    end
  end

  defp text_content(value) do
    %{"type" => "text", "text" => Jason.encode!(value)}
  end
end
