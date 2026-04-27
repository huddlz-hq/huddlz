defmodule HuddlzWeb.Cors do
  @moduledoc false

  def origins do
    Application.get_env(:huddlz, :cors_origins, [])
  end

  def allowed?(_conn, origin), do: matches?(origin, origins())

  def matches?(_origin, :all), do: true
  def matches?(origin, list) when is_list(list), do: origin in list
  def matches?(_origin, _), do: false
end
