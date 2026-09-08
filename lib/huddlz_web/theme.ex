defmodule HuddlzWeb.Theme do
  @moduledoc """
  Resolves a user's theme preference into the `data-theme` attribute the
  root layout puts on `<html>`.

  `:system` (and signed-out visitors) get no attribute, so the stylesheet's
  `prefers-color-scheme` rules decide. `:light` and `:dark` pin the theme.
  """

  @spec html_attr(map() | nil) :: String.t() | nil
  def html_attr(%{theme_preference: theme}) when theme in [:light, :dark],
    do: Atom.to_string(theme)

  def html_attr(_), do: nil
end
