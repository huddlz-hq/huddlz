defmodule HuddlzWeb.AuthFormErrors do
  @moduledoc """
  Keeps authentication form errors clear without weakening domain validation.
  """

  @required_messages ["is required", "must be present"]
  @password_fields [:current_password, :password, :password_confirmation]
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

  def post_process(_form, _path, {:password, message, _vars})
      when message in [
             "length must be greater than or equal to %{min}",
             "length must be greater than or equal to 8"
           ] do
    {:password, "Password must be at least 8 characters.", []}
  end

  def post_process(
        _form,
        _path,
        {field, message, _vars}
      )
      when field in [:password, :password_confirmation] and
             message in ["does not match", "confirmation did not match value"] do
    {:password_confirmation, "Passwords do not match.", []}
  end

  def post_process(_form, _path, {field, "is required", _vars})
      when field in @password_fields do
    {field, required_message(field), []}
  end

  def post_process(_form, _path, error), do: error

  defp required_message(:current_password), do: "Current password is required."
  defp required_message(:password), do: "Password is required."

  defp required_message(:password_confirmation),
    do: "Password confirmation is required."
end
