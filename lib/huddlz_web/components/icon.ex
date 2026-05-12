defmodule HuddlzWeb.Components.Icon do
  @moduledoc """
  Renders a [Heroicon](https://heroicons.com).
  """
  use Phoenix.Component

  attr :name, :string, required: true
  attr :class, :string, default: "size-4"

  def icon(%{name: "hero-" <> _} = assigns) do
    ~H"""
    <span class={[@name, @class]} />
    """
  end
end
