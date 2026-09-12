defmodule Huddlz.Test.FailingMailAdapter do
  @moduledoc "A Swoosh adapter that refuses every delivery, for scenarios where email cannot be sent."
  use Swoosh.Adapter

  @impl true
  def deliver(_email, _config), do: {:error, :mailer_down}
end
