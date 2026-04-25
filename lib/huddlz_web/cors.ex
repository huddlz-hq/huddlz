defmodule HuddlzWeb.Cors do
  @moduledoc false

  def origins do
    Application.get_env(:huddlz, :cors_origins, [])
  end

  def allowed?(_conn, origin) do
    case origins() do
      :all -> true
      list when is_list(list) -> origin in list
      _ -> false
    end
  end
end
