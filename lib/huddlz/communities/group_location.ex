defmodule Huddlz.Communities.GroupLocation do
  @moduledoc """
  An address book location: a place (Google place id and coordinates), the
  organizer's own address text for it, and an optional friendly name. Nothing
  about an entry has to be unique; organizers tidy their own address book.
  """

  use Ash.Resource,
    otp_app: :huddlz,
    domain: Huddlz.Communities,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshPaperTrail.Resource, AshJsonApi.Resource, AshGraphql.Resource]

  graphql do
    type :group_location

    queries do
      list :group_locations, :by_group
    end

    mutations do
      create :create_group_location, :create
      update :update_group_location, :update
      destroy :delete_group_location, :destroy
    end
  end

  json_api do
    type "group_location"

    routes do
      base "/group_locations"

      index :by_group, route: "/by_group"
      post :create
      patch :update
      delete :destroy
    end
  end

  paper_trail do
    change_tracking_mode :snapshot
    store_action_name? true
    reference_source? false
    sensitive_attributes :ignore
    ignore_attributes [:inserted_at, :updated_at]
    belongs_to_actor :actor, Huddlz.Accounts.User, domain: Huddlz.Accounts, on_delete: :nilify
    metadata :impersonation_id, :uuid
    metadata :impersonator_id, :uuid
    metadata :automatic?, :boolean
    version_extensions authorizers: [Ash.Policy.Authorizer]
    mixin {Huddlz.Audit.Version, :mixin, []}
  end

  postgres do
    table "group_locations"
    repo Huddlz.Repo

    references do
      reference :group, on_delete: :delete
    end
  end

  actions do
    defaults [:read]

    destroy :destroy do
      primary? true
      require_atomic? false
      change Huddlz.Communities.GroupLocation.Changes.PreventScheduledDeletion
    end

    create :create do
      primary? true
      accept [:name, :address, :place_id, :latitude, :longitude, :time_zone, :group_id]
    end

    update :update do
      primary? true
      accept [:name, :address]
      require_atomic? false

      validate present(:name) do
        where changing(:name)
        message "Name is required"
      end
    end

    read :by_group do
      argument :group_id, :uuid, allow_nil?: false
      filter expr(group_id == ^arg(:group_id))
      prepare build(sort: [name: :asc])
    end
  end

  policies do
    # Background maintenance retains its existing policies. A signed-in
    # actor must prove address ownership before mutating community data.
    policy [action_type([:create, :update, :destroy]), actor_present()] do
      authorize_if Huddlz.Accounts.Checks.ConfirmedActor
    end

    policy action(:create) do
      authorize_if Huddlz.Communities.Huddl.Checks.GroupOwnerOrOrganizer
    end

    # Locations belong to a group. Mirror the Group read policy so a private
    # group's saved meeting addresses are only visible to its members, while
    # public groups' locations stay readable by anyone (including anonymous).
    policy action_type(:read) do
      authorize_if expr(group.is_public == true and is_nil(group.archived_at))
      authorize_if relates_to_actor_via([:group, :members])
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

  changes do
    change Huddlz.Communities.Changes.RequireActiveGroup, on: [:create, :update, :destroy]
    change Huddlz.Communities.GroupLocation.Changes.NormalizeAddress, on: [:create, :update]
  end

  validations do
    validate Huddlz.TimeZone.Validation do
      where action_is(:create)
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? true
      public? true
      description "Optional friendly name (e.g., 'Community Center')"
      constraints max_length: 200
    end

    attribute :address, :string do
      allow_nil? false
      public? true
      description "The organizer's address text, filled in from the place and freely editable"
      constraints min_length: 1, max_length: 500
    end

    attribute :place_id, :string do
      allow_nil? true
      public? true

      description "Google place id, when known; lets map links open exactly this place"
      constraints max_length: 300
    end

    attribute :latitude, :float do
      allow_nil? false
      public? true
      constraints min: -90, max: 90
    end

    attribute :longitude, :float do
      allow_nil? false
      public? true
      constraints min: -180, max: 180
    end

    attribute :time_zone, :string do
      allow_nil? false
      public? true
      constraints min_length: 1, max_length: 100
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :group, Huddlz.Communities.Group do
      read_action :read_with_archived
      attribute_type :uuid
      allow_nil? false
    end

    has_many :huddlz, Huddlz.Communities.Huddl do
      destination_attribute :group_location_id
    end
  end
end
