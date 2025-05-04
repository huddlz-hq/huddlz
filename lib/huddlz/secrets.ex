defmodule Huddlz.Secrets do
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
