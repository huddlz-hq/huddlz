defmodule Huddlz.Accounts.OauthRefreshToken do
  @moduledoc false
  use Ash.Resource,
    otp_app: :huddlz,
    domain: Huddlz.Accounts,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshAuthentication.Oauth2Server.RefreshTokenResource],
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "oauth_refresh_tokens"
    repo Huddlz.Repo
  end

  actions do
    defaults [:read, :destroy]

    create :issue do
      accept [
        :id,
        :chain_id,
        :generation,
        :token_hash,
        :client_id,
        :user_id,
        :scope,
        :resource_uri,
        :expires_at
      ]
    end

    update :rotate do
      argument :rotated_to_id, :uuid_v7, allow_nil?: false
      accept []

      change AshAuthentication.Oauth2Server.Changes.RotateRefreshToken
    end

    update :revoke do
      accept []
      change atomic_update(:revoked_at, expr(now()))
    end
  end

  policies do
    bypass AshAuthentication.Checks.AshAuthenticationInteraction do
      authorize_if always()
    end
  end

  attributes do
    attribute :token_hash, :string do
      allow_nil? false
      public? true
    end

    attribute :client_id, :uuid_v7 do
      allow_nil? false
      public? true
    end

    attribute :user_id, :uuid do
      allow_nil? false
      public? true
    end

    attribute :scope, :string do
      allow_nil? false
      public? true
    end

    attribute :resource_uri, :string do
      allow_nil? false
      public? true
    end

    attribute :expires_at, :utc_datetime_usec do
      allow_nil? false
      public? true
    end

    attribute :chain_id, :uuid_v7 do
      allow_nil? false
      public? true
    end

    attribute :rotated_to_id, :uuid_v7 do
      public? true
    end

    attribute :rotated_at, :utc_datetime_usec do
      public? true
    end

    attribute :revoked_at, :utc_datetime_usec do
      public? true
    end

    attribute :id, :uuid_v7 do
      primary_key? true
      allow_nil? false
      default &Ash.UUIDv7.generate/0
      writable? true
      public? true
    end

    attribute :generation, :integer do
      allow_nil? false
      default 0
      public? true
    end
  end

  identities do
    identity :by_token_hash, [:token_hash]
  end
end
