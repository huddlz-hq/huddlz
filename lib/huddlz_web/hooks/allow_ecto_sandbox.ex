defmodule HuddlzWeb.Hooks.AllowEctoSandbox do
  @moduledoc """
  Allows LiveView processes to access the Ecto sandbox for testing with Wallaby.
  """
  import Phoenix.LiveView
  import Phoenix.Component

  alias Phoenix.Ecto.SQL.Sandbox

  def on_mount(:default, _params, _session, socket) do
    allow_ecto_sandbox(socket)
    {:cont, socket}
  end

  defp allow_ecto_sandbox(socket) do
    %{assigns: %{phoenix_ecto_sandbox: metadata}} =
      assign_new(socket, :phoenix_ecto_sandbox, fn ->
        if connected?(socket), do: get_connect_info(socket, :user_agent)
      end)

    Sandbox.allow(metadata, Application.get_env(:huddlz, :sandbox))
  end
end
