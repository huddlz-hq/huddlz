defmodule Huddlz.Communities.Group do
  @moduledoc """
  A group is a community container that can organize huddlz and manage members.
  """

  use Ash.Resource,
    otp_app: :huddlz,
    domain: Huddlz.Communities,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "groups"
    repo Huddlz.Repo
  end

  actions do
    defaults [:create, :read, :update, :destroy]

    create :create_group do
      description "Create a new group"
      accept [:name, :description, :location, :image_url, :is_public, :owner_id, :slug]

      change Huddlz.Communities.Group.Changes.AddOwnerAsMember
      change Huddlz.Communities.Group.Changes.GenerateSlug
    end

    read :search do
      description "Search for groups by name or description"

      argument :query, :string do
        allow_nil? false
      end

      filter expr(contains(name, ^arg(:query)) or contains(description, ^arg(:query)))
    end

    read :get_by_owner do
      description "Get groups owned by a specific user"

      argument :owner_id, :uuid do
        allow_nil? false
      end

      filter expr(owner_id == ^arg(:owner_id))
    end

    read :get_by_slug do
      description "Get a group by its slug"

      argument :slug, :string do
        allow_nil? false
      end

      get? true
      filter expr(slug == ^arg(:slug))
    end

    update :update_details do
      description "Update group details"
      accept [:name, :description, :location, :image_url, :is_public, :slug]
    end
  end

  policies do
    # Admin bypass - admins can do everything
    bypass actor_attribute_equals(:role, :admin) do
      authorize_if always()
    end

    # Only verified users can create groups, regular users cannot
    policy action(:create_group) do
      forbid_if actor_attribute_equals(:role, :regular)
      authorize_if actor_attribute_equals(:role, :verified)
    end

    # Only the owner can update group details
    policy action(:update_details) do
      authorize_if expr(owner_id == ^actor(:id))
    end

    # Group owner can do anything with their groups (for non-create actions)
    policy action_type([:update, :destroy]) do
      # Explicitly forbid users that are not the owner
      forbid_unless relates_to_actor_via(:owner)
      authorize_if relates_to_actor_via(:owner)
    end

    # Anyone can read public groups, owner and members can read private groups
    policy action_type(:read) do
      description "Allow reading public groups or groups the actor is related to"
      authorize_if expr(is_public == true)
      authorize_if relates_to_actor_via(:members)
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :ci_string do
      allow_nil? false
      constraints min_length: 3, max_length: 100
    end

    attribute :description, :ci_string do
      allow_nil? true
    end

    attribute :location, :string do
      allow_nil? true
    end

    attribute :image_url, :string do
      allow_nil? true
    end

    attribute :is_public, :boolean do
      allow_nil? false
      default true
    end

    attribute :slug, :string do
      allow_nil? false
      public? true
    end

    create_timestamp :created_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :owner, Huddlz.Accounts.User do
      attribute_type :uuid
      allow_nil? false
      primary_key? false
    end

    many_to_many :members, Huddlz.Accounts.User do
      through Huddlz.Communities.GroupMember
      source_attribute_on_join_resource :group_id
      destination_attribute_on_join_resource :user_id
    end

    has_many :huddlz, Huddlz.Communities.Huddl do
      destination_attribute :group_id
    end
  end

  identities do
    identity :unique_name, [:name]
    identity :unique_slug, [:slug]
  end
end
