defmodule Huddlz.Oauth2Server do
  @moduledoc """
  OAuth 2.1 authorization-server configuration.

  See `AshAuthentication.Oauth2Server` for all options.
  """

  use AshAuthentication.Oauth2Server,
    otp_app: :huddlz,
    user_resource: Huddlz.Accounts.User,
    issuer_url: {Huddlz.Secrets, []},
    resource_url: {Huddlz.Secrets, []},
    signing_secret: {Huddlz.Secrets, []},
    client_resource: Huddlz.Accounts.OauthClient,
    authorization_code_resource: Huddlz.Accounts.OauthAuthorizationCode,
    refresh_token_resource: Huddlz.Accounts.OauthRefreshToken,
    consent_resource: Huddlz.Accounts.OauthConsent,
    scopes: ["mcp"],
    access_token_lifetime: {5, :minutes},
    # Dynamic client registration (RFC 7591). The library default is
    # `false` for safety; the installer turns it on because most
    # people setting up an OAuth server today need it for MCP-style
    # flows (ChatGPT Apps SDK, Claude.ai connectors, etc.). Set to
    # `false` if your auth server is for a fixed set of first-party
    # clients only.
    dcr_enabled?: true,
    # Client ID Metadata Documents — clients identify with an HTTPS
    # URL pointing at their metadata. This is the registration
    # mechanism the MCP spec (2026-07-28) recommends; DCR above is
    # kept for backwards compatibility. Set to `false` if your auth
    # server is for a fixed set of first-party clients only.
    cimd_enabled?: true,
    sign_in_path: "/sign-in"
end
