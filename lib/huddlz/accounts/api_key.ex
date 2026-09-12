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
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshPaperTrail.Resource]

  postgres do
    table "api_keys"
    repo Huddlz.Repo

    references do
      reference :user, on_delete: :delete
    end

    custom_indexes do
      index [:user_id]
    end
  end

  paper_trail do
    change_tracking_mode :snapshot
    store_action_name? true
    reference_source? false
    sensitive_attributes :ignore
    ignore_attributes [:inserted_at, :updated_at, :api_key_hash]
    belongs_to_actor :actor, Huddlz.Accounts.User, domain: Huddlz.Accounts, on_delete: :nilify
    metadata :impersonation_id, :uuid
    metadata :impersonator_id, :uuid
    metadata :automatic?, :boolean
    version_extensions authorizers: [Ash.Policy.Authorizer]
    mixin {Huddlz.Audit.Version, :mixin, []}
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

    policy action(:read) do
      description "Users can read their own API keys"
      authorize_if expr(user_id == ^actor(:id))
    end

    policy action(:destroy) do
      description "Users can revoke their own API keys"
      authorize_if expr(user_id == ^actor(:id))
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
    belongs_to :user, Huddlz.Accounts.User do
      allow_nil? false
    end
  end

  calculations do
    calculate :valid, :boolean, expr(expires_at > now())
  end

  identities do
    identity :unique_api_key, [:api_key_hash]
  end
end
