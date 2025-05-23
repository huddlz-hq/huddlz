defmodule Huddlz.Secrets do
  @moduledoc """
  Handles secret configuration for AshAuthentication tokens.
  """

  use AshAuthentication.Secret

  def secret_for(
        [:authentication, :tokens, :signing_secret],
        Huddlz.Accounts.User,
        _opts,
        _context
      ) do
    Application.fetch_env(:huddlz, :token_signing_secret)
  end
end
