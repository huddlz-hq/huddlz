defmodule HuddlzWeb.ApiAuth do
  @moduledoc """
  Helpers for the API authentication pipelines.

  `AshAuthentication.Strategy.ApiKey.Plug` co-exists with `:load_from_bearer`:
  both inspect the `Authorization: Bearer <token>` header. When the bearer is
  a JWT (already validated by `:load_from_bearer`), the API-key plug fails to
  match it as an API key. `continue/2` is its `on_error` callback in that
  situation — it leaves the conn alone so the previously set actor stands.
  """

  @doc "Pass-through on_error callback for the API key plug."
  def continue(conn, _error), do: conn
end
