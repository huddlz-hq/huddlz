defmodule Huddlz.Accounts.User do
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
      upsert_fields [:email, :display_name]

      # Generate a random display name if one isn't provided
      change before_action(fn changeset, _context ->
               if Ash.Changeset.get_attribute(changeset, :display_name) do
                 changeset
               else
                 display_name = generate_random_display_name()
                 Ash.Changeset.change_attribute(changeset, :display_name, display_name)
               end
             end)

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
      description "Name the user wants others to idenify them as"
      allow_nil? true
      public? true
    end

    attribute :role, Huddlz.Accounts.Role do
      description "User's role determines their permissions in the system"
      allow_nil? false
      default :regular
    end
  end

  identities do
    identity :unique_email, [:email]
  end

  # Helper function to generate a random display name
  def generate_random_display_name do
    adjectives = [
      "Happy",
      "Clever",
      "Gentle",
      "Brave",
      "Wise",
      "Cool",
      "Brilliant",
      "Swift",
      "Calm",
      "Daring"
    ]

    nouns = [
      "Dolphin",
      "Tiger",
      "Eagle",
      "Panda",
      "Wolf",
      "Falcon",
      "Bear",
      "Fox",
      "Lion",
      "Hawk"
    ]

    random_number = :rand.uniform(999)

    "#{Enum.random(adjectives)}#{Enum.random(nouns)}#{random_number}"
  end
end
