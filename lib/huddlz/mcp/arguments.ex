defmodule Huddlz.Mcp.Arguments do
  @moduledoc "Reject misplaced tool parameters instead of silently broadening a search."

  def validate(_tool, %{"input" => input} = arguments, _context)
      when is_map(input) and map_size(arguments) == 1,
      do: {:ok, arguments}

  def validate(_tool, arguments, _context) when is_map(arguments) and map_size(arguments) == 0,
    do: {:ok, arguments}

  def validate(_tool, _arguments, _context),
    do: {:error, "Tool arguments must contain only an input object matching the tool schema."}
end
