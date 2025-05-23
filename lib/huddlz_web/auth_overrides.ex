defmodule HuddlzWeb.AuthOverrides do
  @moduledoc """
  Custom authentication component overrides for the Huddlz application.
  """

  use AshAuthentication.Phoenix.Overrides

  override AshAuthentication.Phoenix.Components.SignIn do
    set :strategy_class, "w-full"
  end

  override AshAuthentication.Phoenix.Components.MagicLink do
    set :disable_button_text, "Sending magic link..."
  end

  # Add a custom banner for user account pages
  override AshAuthentication.Phoenix.Components.Banner do
    set :text_class, "font-medium text-indigo-600"
  end
end
