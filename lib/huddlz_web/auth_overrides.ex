defmodule HuddlzWeb.AuthOverrides do
  use AshAuthentication.Phoenix.Overrides

  def overrides do
    %{
      {AshAuthentication.Phoenix.Components.SignIn, :strategy_class} => "w-full",
      {AshAuthentication.Phoenix.Components.MagicLink, :disable_button_text} =>
        "Sending magic link..."
    }
  end
end
