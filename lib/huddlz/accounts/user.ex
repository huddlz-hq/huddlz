defmodule Huddlz.Accounts.User do
  @moduledoc """
  User resource with authentication capabilities and role-based permissions.
  """

  use Ash.Resource,
    otp_app: :huddlz,
    domain: Huddlz.Accounts,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshAuthentication],
    data_layer: AshPostgres.DataLayer

  authentication do
    add_ons do
      log_out_everywhere do
        apply_on_password_change? true
      end
    end

    tokens do
      enabled? true
      token_resource Huddlz.Accounts.Token
      signing_secret Huddlz.Secrets
      store_all_tokens? true
      require_token_presence_for_authentication? true
    end

    strategies do
      magic_link do
        identity_field :email
        registration_enabled? true

        sender Huddlz.Accounts.User.Senders.SendMagicLinkEmail
      end
    end
  end

  postgres do
    table "users"
    repo Huddlz.Repo

    custom_indexes do
      index "email gin_trgm_ops", name: "users_email_gin_index", using: "GIN"
    end
  end

  actions do
    defaults [:read]

    create :create do
      accept [:email, :display_name, :role]

      change Huddlz.Accounts.User.Changes.SetDefaultDisplayName
    end

    read :get_by_subject do
      description "Get a user by the subject claim in a JWT"
      argument :subject, :string, allow_nil?: false
      get? true
      prepare AshAuthentication.Preparations.FilterBySubject
    end

    read :get_by_email do
      description "Looks up a user by their email"
      get? true

      argument :email, :ci_string do
        allow_nil? false
      end

      filter expr(email == ^arg(:email))
    end

    read :search_by_email do
      description "Searches for users by partial email match"

      argument :email, :string do
        constraints allow_empty?: true
        default ""
      end

      filter expr(contains(email, ^arg(:email)))
      prepare Huddlz.Accounts.User.Preparations.AdminOnlySearch
    end

    create :sign_in_with_magic_link do
      description "Sign in or register a user with magic link."

      argument :token, :string do
        description "The token from the magic link that was sent to the user"
        allow_nil? false
      end

      argument :display_name, :string do
        description "The user's display name"
        allow_nil? true
      end

      upsert? true
      upsert_identity :unique_email
      upsert_fields [:email]

      # Generate a random display name only for new users
      change Huddlz.Accounts.User.Changes.SetDefaultDisplayName

      # Uses the information from the token to create or sign in the user
      change AshAuthentication.Strategy.MagicLink.SignInChange

      metadata :token, :string do
        allow_nil? false
      end
    end

    action :request_magic_link do
      argument :email, :ci_string do
        allow_nil? false
      end

      run AshAuthentication.Strategy.MagicLink.Request
    end

    update :update_display_name do
      description "Update a user's display_name"
      accept [:display_name]

      validate string_length(:display_name, min: 3, max: 30)
    end

    update :update_role do
      description "Update a user's role"
      accept [:role]
    end
  end

  policies do
    bypass AshAuthentication.Checks.AshAuthenticationInteraction do
      authorize_if always()
    end

    bypass actor_attribute_equals(:role, :admin) do
      authorize_if always()
    end

    # Basic read permissions - needed for auth
    policy action(:read) do
      authorize_if always()
    end

    policy action(:get_by_subject) do
      authorize_if always()
    end

    policy action(:get_by_email) do
      authorize_if always()
    end

    policy action(:search_by_email) do
      description "All users can search, but results are filtered"
      authorize_if always()
    end

    policy action(:update_display_name) do
      description "Users can update their own display_name"
      authorize_if expr(id == ^actor(:id))
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :email, :ci_string do
      allow_nil? false
      public? true
    end

    attribute :display_name, :string do
      description "Name the user wants others to identify them as"
      allow_nil? true
      public? true
      constraints min_length: 3, max_length: 30
    end

    attribute :role, Huddlz.Accounts.Role do
      description "User's role determines their permissions in the system"
      allow_nil? false
      default :regular
    end
  end

  relationships do
    has_many :rsvps, Huddlz.Communities.HuddlAttendee do
      destination_attribute :user_id
    end
  end

  identities do
    identity :unique_email, [:email]
  end
end
