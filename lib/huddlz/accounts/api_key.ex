defmodule Huddlz.Accounts.ApiKey do
  @moduledoc """
  API keys for machine-to-machine authentication.

  Plaintext keys are returned only at create time via the
  `plaintext_api_key` metadata; only the hash is persisted.
  """

  use Ash.Resource,
    otp_app: :huddlz,
    domain: Huddlz.Accounts,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "api_keys"
    repo Huddlz.Repo
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:expires_at]

      change relate_actor(:user)

      change {AshAuthentication.Strategy.ApiKey.GenerateApiKey,
              prefix: :huddlz, hash: :api_key_hash}
    end
  end

  policies do
    bypass AshAuthentication.Checks.AshAuthenticationInteraction do
      authorize_if always()
    end

    policy action(:create) do
      description "Authenticated users can create API keys for themselves"
      authorize_if actor_present()
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :api_key_hash, :binary do
      allow_nil? false
      sensitive? true
    end

    attribute :expires_at, :utc_datetime_usec do
      allow_nil? false
    end
  end

  relationships do
    belongs_to :user, Huddlz.Accounts.User
  end

  calculations do
    calculate :valid, :boolean, expr(expires_at > now())
  end

  identities do
    identity :unique_api_key, [:api_key_hash]
  end
end
