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

      confirmation :confirm_new_user do
        monitor_fields [:email]
        confirm_on_create? true
        confirm_on_update? false
        require_interaction? true
        confirmed_at_field :confirmed_at
        auto_confirm_actions [:reset_password_with_token]
        sender Huddlz.Accounts.User.Senders.SendNewUserConfirmationEmail
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
      password :password do
        identity_field :email
        hash_provider AshAuthentication.BcryptProvider

        resettable do
          sender Huddlz.Accounts.User.Senders.SendPasswordResetEmail
          # these configurations will be the default in a future release
          password_reset_action_name :reset_password_with_token
          request_password_reset_action_name :request_password_reset_token
        end
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
      # For testing/seeding only - use authentication actions in production
      primary? true
      accept [:email, :display_name, :role, :confirmed_at, :hashed_password]
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

    update :update_display_name do
      description "Update a user's display_name"
      accept [:display_name]

      validate attribute_does_not_equal(:display_name, "")
      validate string_length(:display_name, min: 1, max: 70)
    end

    update :update_role do
      description "Update a user's role"
      accept [:role]
    end

    update :change_password do
      # Use this action to allow users to change their password by providing
      # their current password and a new password.

      require_atomic? false
      accept []
      argument :current_password, :string, sensitive?: true, allow_nil?: false

      argument :password, :string,
        sensitive?: true,
        allow_nil?: false,
        constraints: [min_length: 8]

      argument :password_confirmation, :string, sensitive?: true, allow_nil?: false

      validate confirm(:password, :password_confirmation)

      validate {AshAuthentication.Strategy.Password.PasswordValidation,
                strategy_name: :password, password_argument: :current_password}

      change {AshAuthentication.Strategy.Password.HashPasswordChange, strategy_name: :password}
    end

    update :set_password do
      # Use this action to allow users to set their password when they don't have one yet.

      require_atomic? false
      accept []

      argument :password, :string,
        sensitive?: true,
        allow_nil?: false,
        constraints: [min_length: 8]

      argument :password_confirmation, :string, sensitive?: true, allow_nil?: false

      validate confirm(:password, :password_confirmation)

      change {AshAuthentication.Strategy.Password.HashPasswordChange, strategy_name: :password}
    end

    read :sign_in_with_password do
      description "Attempt to sign in using a email and password."
      get? true

      argument :email, :ci_string do
        description "The email to use for retrieving the user."
        allow_nil? false
      end

      argument :password, :string do
        description "The password to check for the matching user."
        allow_nil? false
        sensitive? true
      end

      # validates the provided email and password and generates a token
      prepare AshAuthentication.Strategy.Password.SignInPreparation

      metadata :token, :string do
        description "A JWT that can be used to authenticate the user."
        allow_nil? false
      end
    end

    read :sign_in_with_token do
      # In the generated sign in components, we validate the
      # email and password directly in the LiveView
      # and generate a short-lived token that can be used to sign in over
      # a standard controller action, exchanging it for a standard token.
      # This action performs that exchange. If you do not use the generated
      # liveviews, you may remove this action, and set
      # `sign_in_tokens_enabled? false` in the password strategy.

      description "Attempt to sign in using a short-lived sign in token."
      get? true

      argument :token, :string do
        description "The short-lived sign in token."
        allow_nil? false
        sensitive? true
      end

      # validates the provided sign in token and generates a token
      prepare AshAuthentication.Strategy.Password.SignInWithTokenPreparation

      metadata :token, :string do
        description "A JWT that can be used to authenticate the user."
        allow_nil? false
      end
    end

    create :register_with_password do
      description "Register a new user with a email and password."
      accept [:email, :display_name]

      argument :password, :string do
        description "The proposed password for the user, in plain text."
        allow_nil? false
        constraints min_length: 8
        sensitive? true
      end

      argument :password_confirmation, :string do
        description "The proposed password for the user (again), in plain text."
        allow_nil? false
        sensitive? true
      end

      # Hashes the provided password
      change AshAuthentication.Strategy.Password.HashPasswordChange

      # Generates an authentication token for the user
      change AshAuthentication.GenerateTokenChange

      # validates that the password matches the confirmation
      validate AshAuthentication.Strategy.Password.PasswordConfirmationValidation

      metadata :token, :string do
        description "A JWT that can be used to authenticate the user."
        allow_nil? false
      end
    end

    action :request_password_reset_token do
      description "Send password reset instructions to a user if they exist."

      argument :email, :ci_string do
        allow_nil? false
      end

      # creates a reset token and invokes the relevant senders
      run {AshAuthentication.Strategy.Password.RequestPasswordReset, action: :get_by_email}
    end

    update :reset_password_with_token do
      argument :reset_token, :string do
        allow_nil? false
        sensitive? true
      end

      argument :password, :string do
        description "The proposed password for the user, in plain text."
        allow_nil? false
        constraints min_length: 8
        sensitive? true
      end

      argument :password_confirmation, :string do
        description "The proposed password for the user (again), in plain text."
        allow_nil? false
        sensitive? true
      end

      # validates the provided reset token
      validate AshAuthentication.Strategy.Password.ResetTokenValidation

      # validates that the password matches the confirmation
      validate AshAuthentication.Strategy.Password.PasswordConfirmationValidation

      # Hashes the provided password
      change AshAuthentication.Strategy.Password.HashPasswordChange

      # Generates an authentication token for the user
      change AshAuthentication.GenerateTokenChange
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

    policy action(:create) do
      description "Direct creation only for testing/seeding (use authorize?: false)"
      forbid_if always()
    end

    policy action(:register_with_password) do
      description "Anyone can register with password"
      authorize_if always()
    end

    policy action(:sign_in_with_password) do
      description "Anyone can attempt to sign in with password"
      authorize_if always()
    end

    policy action(:request_password_reset_token) do
      description "Anyone can request a password reset"
      authorize_if always()
    end

    policy action(:reset_password_with_token) do
      description "Anyone with a valid token can reset password"
      authorize_if always()
    end

    policy action(:update_display_name) do
      description "Users can update their own display_name"
      authorize_if expr(id == ^actor(:id))
    end

    policy action(:change_password) do
      description "Users can change their own password"
      authorize_if expr(id == ^actor(:id))
    end

    policy action(:set_password) do
      description "Users can set their own password"
      authorize_if expr(id == ^actor(:id))
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :email, :ci_string do
      allow_nil? false
      public? true
      constraints match: ~S/^[^\s]+@[^\s]+$/
    end

    attribute :display_name, :string do
      description "Name the user wants others to identify them as"
      allow_nil? false
      public? true
      constraints min_length: 1, max_length: 70
    end

    attribute :role, Huddlz.Accounts.Role do
      description "User's role determines their permissions in the system"
      allow_nil? false
      default :user
    end

    attribute :hashed_password, :string do
      sensitive? true
    end

    attribute :confirmed_at, :utc_datetime_usec do
      # Allow setting for testing/seeding purposes
      public? true
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
