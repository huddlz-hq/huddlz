defmodule Huddlz.Accounts.UserAddress do
  @moduledoc """
  Stores geocoded address data for users.

  Addresses are optional and can be added during registration or later
  from profile settings. Stores both the formatted address and geocoded
  components for future search functionality (e.g., finding nearby huddlz).

  Each user can have at most one address (enforced by unique identity).
  """

  use Ash.Resource,
    otp_app: :huddlz,
    domain: Huddlz.Accounts,
    authorizers: [Ash.Policy.Authorizer],
    data_layer: AshPostgres.DataLayer

  postgres do
    table "user_addresses"
    repo Huddlz.Repo

    custom_indexes do
      index [:user_id]
      # For future geospatial queries (bounding box without PostGIS)
      index [:latitude, :longitude]
      index [:city]
      index [:state]
      index [:country]
    end
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      description "Create an address for a user"
      primary? true

      accept [
        :formatted_address,
        :latitude,
        :longitude,
        :street_number,
        :street_name,
        :city,
        :state,
        :postal_code,
        :country,
        :country_name,
        :place_id,
        :user_id
      ]
    end

    update :update do
      description "Update a user's address"
      primary? true

      accept [
        :formatted_address,
        :latitude,
        :longitude,
        :street_number,
        :street_name,
        :city,
        :state,
        :postal_code,
        :country,
        :country_name,
        :place_id
      ]
    end

    read :get_for_user do
      description "Get the address for a specific user"
      get? true

      argument :user_id, :uuid do
        allow_nil? false
      end

      filter expr(user_id == ^arg(:user_id))
    end
  end

  policies do
    bypass actor_attribute_equals(:role, :admin) do
      authorize_if always()
    end

    # Users can create their own address
    policy action(:create) do
      description "Users can only create addresses for themselves"
      authorize_if expr(user_id == ^actor(:id))
    end

    # Users can update their own address
    policy action(:update) do
      description "Users can only update their own address"
      authorize_if relates_to_actor_via(:user)
    end

    # Users can delete their own address
    policy action(:destroy) do
      description "Users can only delete their own address"
      authorize_if relates_to_actor_via(:user)
    end

    # Users can read their own address (addresses are private)
    policy action_type(:read) do
      description "Users can only read their own address"
      authorize_if relates_to_actor_via(:user)
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :formatted_address, :string do
      allow_nil? false
      public? true
      description "Full formatted address from Google Places"
    end

    attribute :latitude, :decimal do
      allow_nil? false
      public? true
      constraints precision: 10, scale: 7
      description "Latitude coordinate"
    end

    attribute :longitude, :decimal do
      allow_nil? false
      public? true
      constraints precision: 10, scale: 7
      description "Longitude coordinate"
    end

    attribute :street_number, :string do
      allow_nil? true
      public? true
      description "Street number (e.g., '123')"
    end

    attribute :street_name, :string do
      allow_nil? true
      public? true
      description "Street name (e.g., 'Main St')"
    end

    attribute :city, :string do
      allow_nil? true
      public? true
      description "City or locality name"
    end

    attribute :state, :string do
      allow_nil? true
      public? true
      description "State/province abbreviation (e.g., 'CA')"
    end

    attribute :postal_code, :string do
      allow_nil? true
      public? true
      description "Postal/ZIP code"
    end

    attribute :country, :string do
      allow_nil? true
      public? true
      description "Country code (e.g., 'US')"
    end

    attribute :country_name, :string do
      allow_nil? true
      public? true
      description "Full country name (e.g., 'United States')"
    end

    attribute :place_id, :string do
      allow_nil? true
      public? true
      description "Google Places ID for future lookups"
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :user, Huddlz.Accounts.User do
      attribute_type :uuid
      allow_nil? false
      public? true
    end
  end

  identities do
    identity :unique_user, [:user_id], message: "User already has an address"
  end
end
