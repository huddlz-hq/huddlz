defmodule Huddlz.Communities.GroupLocation do
  @moduledoc """
  A saved location in a group's address book.
  Stores geocoded coordinates so locations can be reused without re-geocoding.
  """

  use Ash.Resource,
    otp_app: :huddlz,
    domain: Huddlz.Communities,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "group_locations"
    repo Huddlz.Repo

    references do
      reference :group, on_delete: :delete
    end
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:name, :address, :latitude, :longitude, :group_id]
    end

    update :update do
      primary? true
      accept [:name]
      require_atomic? false
    end

    read :by_group do
      argument :group_id, :uuid, allow_nil?: false
      filter expr(group_id == ^arg(:group_id))
      prepare build(sort: [name: :asc])
    end
  end

  policies do
    bypass actor_attribute_equals(:role, :admin) do
      authorize_if always()
    end

    policy action(:create) do
      authorize_if Huddlz.Communities.Huddl.Checks.GroupOwnerOrOrganizer
    end

    policy action_type(:read) do
      authorize_if always()
    end

    policy action_type([:update, :destroy]) do
      authorize_if expr(group.owner_id == ^actor(:id))

      authorize_if expr(
                     exists(
                       group.group_members,
                       user_id == ^actor(:id) and role == :organizer
                     )
                   )
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? true
      description "Optional friendly name (e.g., 'Community Center')"
      constraints max_length: 200
    end

    attribute :address, :string do
      allow_nil? false
      description "Full address string from Google Places"
      constraints min_length: 1, max_length: 500
    end

    attribute :latitude, :float do
      allow_nil? false
      constraints min: -90, max: 90
    end

    attribute :longitude, :float do
      allow_nil? false
      constraints min: -180, max: 180
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :group, Huddlz.Communities.Group do
      attribute_type :uuid
      allow_nil? false
    end
  end

  identities do
    identity :unique_name_per_group, [:group_id, :name],
      nils_distinct?: false,
      pre_check?: true
  end
end
