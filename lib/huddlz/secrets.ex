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

  def secret_for([:issuer_url], Huddlz.Oauth2Server, _opts, _context) do
    Application.fetch_env(:huddlz, :oauth2_issuer_url)
  end

  def secret_for([:resource_url], Huddlz.Oauth2Server, _opts, _context) do
    Application.fetch_env(:huddlz, :oauth2_resource_url)
  end

  def secret_for([:signing_secret], Huddlz.Oauth2Server, _opts, _context) do
    Application.fetch_env(:huddlz, :oauth2_signing_secret)
  end
end
