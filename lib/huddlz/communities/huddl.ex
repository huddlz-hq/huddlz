defmodule Huddlz.Communities.Huddl do
  @moduledoc """
  A huddl represents an event or gathering within the Huddlz platform.
  """

  use Ash.Resource,
    otp_app: :huddlz,
    domain: Huddlz.Communities,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshJsonApi.Resource, AshGraphql.Resource],
    primary_read_warning?: false

  graphql do
    type :huddl

    queries do
      get :get_huddl, :read
      list :search_huddlz, :search
    end
  end

  json_api do
    type "huddl"

    routes do
      base "/huddlz"

      get :read
      index :search
    end
  end

  postgres do
    table "huddlz"
    repo Huddlz.Repo

    custom_indexes do
      index "ST_MakePoint(longitude, latitude)",
        name: "huddlz_location_gist_index",
        using: "GIST",
        where: "latitude IS NOT NULL AND longitude IS NOT NULL"
    end
  end

  actions do
    defaults [:destroy]

    read :read do
      primary? true
      prepare Huddlz.Communities.Huddl.Preparations.FilterByVisibility
    end

    create :create do
      primary? true

      accept [
        :title,
        :description,
        :starts_at,
        :ends_at,
        :event_type,
        :physical_location,
        :virtual_link,
        :is_private,
        :thumbnail_url,
        :creator_id,
        :group_id,
        :huddl_template_id
      ]

      # Virtual arguments for form inputs
      argument :date, :date, allow_nil?: true
      argument :start_time, :time, allow_nil?: true

      argument :duration_minutes, :integer do
        allow_nil? true
        constraints min: 15, max: 1440
      end

      argument :is_recurring, :boolean, default: false
      argument :repeat_until, :date, allow_nil?: true
      argument :frequency, :string, allow_nil?: true

      validate Huddlz.Communities.Huddl.Validations.FutureDateValidation
      change Huddlz.Communities.Huddl.Changes.CalculateDateTimeFromInputs
      change Huddlz.Communities.Huddl.Changes.ForcePrivateForPrivateGroups
      change Huddlz.Communities.Huddl.Changes.AddHuddlTemplate
      change Huddlz.Communities.Huddl.Changes.GeocodeLocation
      change Huddlz.Communities.Huddl.Changes.DefaultLocationFromGroup
    end

    update :update do
      primary? true

      accept [
        :title,
        :description,
        :starts_at,
        :ends_at,
        :event_type,
        :physical_location,
        :virtual_link,
        :is_private,
        :thumbnail_url,
        :huddl_template_id
      ]

      # Virtual arguments for form inputs
      argument :date, :date, allow_nil?: true
      argument :start_time, :time, allow_nil?: true

      argument :duration_minutes, :integer do
        allow_nil? true
        constraints min: 15, max: 1440
      end

      argument :repeat_until, :date
      argument :frequency, :string

      argument :edit_type, :string do
        constraints allow_empty?: true
        default "instance"
      end

      require_atomic? false

      change Huddlz.Communities.Huddl.Changes.CalculateDateTimeFromInputs
      change Huddlz.Communities.Huddl.Changes.EditRecurringHuddlz
      change Huddlz.Communities.Huddl.Changes.GeocodeLocation
      change Huddlz.Communities.Huddl.Changes.DefaultLocationFromGroup
    end

    read :by_status do
      argument :status, :atom do
        allow_nil? false
        constraints one_of: [:draft, :upcoming, :in_progress, :completed, :cancelled]
      end

      filter expr(status == ^arg(:status))
      prepare Huddlz.Communities.Huddl.Preparations.FilterByVisibility
    end

    read :upcoming do
      filter expr(ends_at > now())
      prepare Huddlz.Communities.Huddl.Preparations.FilterByVisibility
      prepare build(sort: [starts_at: :asc])
    end

    read :past do
      filter expr(ends_at < now())
      prepare Huddlz.Communities.Huddl.Preparations.FilterByVisibility
      prepare build(sort: [starts_at: :desc])
    end

    read :search do
      argument :query, :ci_string do
        allow_nil? true
      end

      argument :date_filter, :atom do
        allow_nil? false
        default :upcoming
        constraints one_of: [:upcoming, :this_week, :this_month, :past, :all]
      end

      argument :event_type, :atom do
        allow_nil? true
        constraints one_of: [:in_person, :virtual, :hybrid]
      end

      argument :search_latitude, :float, allow_nil?: true
      argument :search_longitude, :float, allow_nil?: true

      argument :distance_miles, :integer do
        allow_nil? true
        default 25
        constraints min: 5, max: 100
      end

      pagination keyset?: true,
                 offset?: true,
                 countable: true,
                 required?: false,
                 default_limit: 20

      prepare Huddlz.Communities.Huddl.Preparations.FilterByVisibility
      prepare Huddlz.Communities.Huddl.Preparations.ApplySearchFilters
      prepare build(sort: [starts_at: :asc])
    end

    read :by_group do
      argument :group_id, :uuid do
        allow_nil? false
      end

      filter expr(group_id == ^arg(:group_id) and starts_at > now())

      pagination keyset?: true,
                 offset?: true,
                 countable: true,
                 required?: false,
                 default_limit: 10

      prepare Huddlz.Communities.Huddl.Preparations.FilterByVisibility
      prepare build(sort: [starts_at: :asc])
    end

    read :past_by_group do
      argument :group_id, :uuid do
        allow_nil? false
      end

      filter expr(group_id == ^arg(:group_id) and ends_at < now())

      pagination keyset?: true,
                 offset?: true,
                 countable: true,
                 required?: false,
                 default_limit: 10

      prepare Huddlz.Communities.Huddl.Preparations.FilterByVisibility
      prepare build(sort: [starts_at: :desc])
    end

    update :rsvp do
      description "RSVP to this huddl"
      require_atomic? false

      argument :user_id, :uuid do
        allow_nil? false
      end

      change Huddlz.Communities.Huddl.Changes.Rsvp
    end

    update :cancel_rsvp do
      description "Cancel RSVP to this huddl"
      require_atomic? false

      argument :user_id, :uuid do
        allow_nil? false
      end

      change Huddlz.Communities.Huddl.Changes.CancelRsvp
    end
  end

  policies do
    # Admins can do anything
    bypass always() do
      description "Admins can do anything"
      authorize_if actor_attribute_equals(:role, :admin)
    end

    # Creation policies
    policy action(:create) do
      description "Only group owners and organizers can create huddls"
      authorize_if Huddlz.Communities.Huddl.Checks.GroupOwnerOrOrganizer
    end

    # Read policies - visibility filtering is handled by the FilterByVisibility preparation
    # on each read action, which adds database-level filters. We authorize all reads here
    # and rely on the preparation to restrict results.
    policy action_type(:read) do
      description "Users can read huddlz they have access to (filtered by preparation)"
      authorize_if always()
    end

    # RSVP policies
    policy action(:rsvp) do
      description "Users can RSVP to huddlz they have access to"
      forbid_unless expr(^arg(:user_id) == ^actor(:id))
      authorize_if expr(is_private == false and group.is_public == true)
      authorize_if expr(exists(group.members, id == ^actor(:id)))
    end

    # Cancel RSVP policies
    policy action(:cancel_rsvp) do
      description "Users can cancel their own RSVPs"
      forbid_unless expr(^arg(:user_id) == ^actor(:id))
      authorize_if expr(is_private == false and group.is_public == true)
      authorize_if expr(exists(group.members, id == ^actor(:id)))
    end

    # Update and delete policies
    policy action([:update, :destroy]) do
      description "Only group owners and organizers can update or delete huddlz"
      authorize_if expr(group.owner_id == ^actor(:id))

      authorize_if expr(
                     exists(group.group_members, user_id == ^actor(:id) and role == :organizer)
                   )
    end
  end

  # changes section removed - validation is handled by FutureDateValidation module

  validations do
    validate compare(:ends_at, greater_than: :starts_at) do
      message "must be after the start time"
    end

    validate present([:physical_location]) do
      where attribute_equals(:event_type, :in_person)
      message "is required for in-person events"
    end

    validate present([:virtual_link]) do
      where attribute_equals(:event_type, :virtual)
      message "is required for virtual events"
    end

    validate present([:physical_location, :virtual_link]) do
      where attribute_equals(:event_type, :hybrid)
      message "both physical location and virtual link are required for hybrid events"
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :title, :string do
      allow_nil? false
      constraints min_length: 3, max_length: 200
    end

    attribute :description, :string do
      allow_nil? true
    end

    attribute :starts_at, :utc_datetime do
      allow_nil? false
    end

    attribute :ends_at, :utc_datetime do
      allow_nil? false
    end

    attribute :event_type, :atom do
      allow_nil? false
      constraints one_of: [:in_person, :virtual, :hybrid]
      default :in_person
    end

    attribute :physical_location, :string do
      allow_nil? true
    end

    attribute :virtual_link, :string do
      allow_nil? true
      sensitive? true
    end

    attribute :is_private, :boolean do
      allow_nil? false
      default false
    end

    attribute :thumbnail_url, :string do
      allow_nil? true
    end

    attribute :latitude, :float do
      allow_nil? true
      description "Geocoded latitude of physical_location or inherited from group"
    end

    attribute :longitude, :float do
      allow_nil? true
      description "Geocoded longitude of physical_location or inherited from group"
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :creator, Huddlz.Accounts.User do
      attribute_type :uuid
      allow_nil? false
      primary_key? false
    end

    belongs_to :group, Huddlz.Communities.Group do
      attribute_type :uuid
      allow_nil? false
      primary_key? false
    end

    belongs_to :huddl_template, Huddlz.Communities.HuddlTemplate do
      attribute_type :uuid
      allow_nil? true
      primary_key? false
    end

    has_many :attendees, Huddlz.Communities.HuddlAttendee do
      destination_attribute :huddl_id
    end

    has_many :huddl_images, Huddlz.Communities.HuddlImage do
      destination_attribute :huddl_id
    end
  end

  calculations do
    calculate :status, :atom do
      calculation expr(
                    cond do
                      starts_at > now() -> :upcoming
                      ends_at < now() -> :completed
                      true -> :in_progress
                    end
                  )
    end

    calculate :visible_virtual_link, :string do
      description "Returns the virtual link only if the actor has RSVPed to the huddl"

      calculation expr(
                    if exists(attendees, user_id == ^actor(:id)) do
                      virtual_link
                    else
                      nil
                    end
                  )
    end

    calculate :actor_is_member, :boolean do
      description "Whether the current actor is a member of the huddl's group"
      calculation expr(exists(group.members, user_id == ^actor(:id)))
    end

    calculate :is_publicly_visible, :boolean do
      description "Whether the huddl is visible to everyone (public huddl in public group)"
      calculation expr(is_private == false and group.is_public == true)
    end

    calculate :display_image_url, :string do
      description "Returns huddl's image, falling back to group image if none"
      calculation Huddlz.Communities.Huddl.Calculations.DisplayImageUrl
    end
  end

  aggregates do
    count :rsvp_count, :attendees

    first :current_image_url, :huddl_images, :thumbnail_path do
      description "Returns the thumbnail path of the huddl's current image"
      sort inserted_at: :desc
      filter expr(is_nil(deleted_at))
    end
  end
end
