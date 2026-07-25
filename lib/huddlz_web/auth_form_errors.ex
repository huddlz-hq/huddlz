defmodule HuddlzWeb.AuthFormErrors do
  @moduledoc """
  Keeps authentication form errors clear without weakening domain validation.
  """

  @required_messages ["is required", "must be present"]
  @pattern_prefix "must match the pattern"

  def post_process(_form, _path, {:email, message, _vars})
      when message in @required_messages do
    {:email, "Email is required.", []}
  end

  def post_process(_form, _path, {:email, message, vars}) do
    if String.starts_with?(message, @pattern_prefix) do
      {:email, "Enter a valid email address.", []}
    else
      {:email, message, vars}
    end
  end

  def post_process(_form, _path, error), do: error
end
