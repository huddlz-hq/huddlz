defmodule Huddlz.Communities.Huddl do
  @moduledoc """
  A huddl represents an event or gathering within the Huddlz platform.
  """

  use Ash.Resource,
    otp_app: :huddlz,
    domain: Huddlz.Communities,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    primary_read_warning?: false

  postgres do
    table "huddlz"
    repo Huddlz.Repo
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
        :rsvp_count,
        :thumbnail_url,
        :creator_id,
        :group_id
      ]

      change Huddlz.Communities.Huddl.Changes.ForcePrivateForPrivateGroups
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
        :rsvp_count,
        :thumbnail_url
      ]

      require_atomic? false
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
      filter expr(starts_at > ^DateTime.utc_now())
      prepare Huddlz.Communities.Huddl.Preparations.FilterByVisibility
    end

    read :search do
      argument :query, :ci_string do
        allow_nil? true
      end

      filter expr(
               is_nil(^arg(:query)) or contains(title, ^arg(:query)) or
                 contains(description, ^arg(:query))
             )

      prepare Huddlz.Communities.Huddl.Preparations.FilterByVisibility
    end

    read :by_group do
      argument :group_id, :uuid do
        allow_nil? false
      end

      filter expr(group_id == ^arg(:group_id) and starts_at > ^DateTime.utc_now())
      prepare Huddlz.Communities.Huddl.Preparations.FilterByVisibility
      prepare build(sort: [starts_at: :asc])
    end

    update :rsvp do
      description "RSVP to this huddl"
      require_atomic? false

      # Accept the user_id as an argument
      argument :user_id, :uuid do
        allow_nil? false
      end

      # Custom change to handle RSVP
      change fn changeset, _context ->
        user_id = Ash.Changeset.get_argument(changeset, :user_id)
        huddl_id = changeset.data.id

        # Check if already RSVPed
        existing =
          Huddlz.Communities.HuddlAttendee
          |> Ash.Query.for_read(:check_rsvp, %{huddl_id: huddl_id, user_id: user_id})
          |> Ash.read_one(authorize?: false)

        case existing do
          {:ok, nil} ->
            # Create RSVP
            Huddlz.Communities.HuddlAttendee
            |> Ash.Changeset.for_create(:rsvp, %{huddl_id: huddl_id, user_id: user_id})
            |> Ash.create!(authorize?: false)

            # Increment count
            Ash.Changeset.change_attribute(changeset, :rsvp_count, changeset.data.rsvp_count + 1)

          {:ok, _} ->
            # Already RSVPed, no change needed
            changeset

          {:error, error} ->
            Ash.Changeset.add_error(changeset, error)
        end
      end
    end

    update :cancel_rsvp do
      description "Cancel RSVP to this huddl"
      require_atomic? false

      # Accept the user_id as an argument
      argument :user_id, :uuid do
        allow_nil? false
      end

      # Custom change to handle cancellation
      change fn changeset, _context ->
        user_id = Ash.Changeset.get_argument(changeset, :user_id)
        huddl_id = changeset.data.id

        # Find the existing RSVP
        existing =
          Huddlz.Communities.HuddlAttendee
          |> Ash.Query.for_read(:check_rsvp, %{huddl_id: huddl_id, user_id: user_id})
          |> Ash.read_one(authorize?: false)

        case existing do
          {:ok, nil} ->
            # No RSVP to cancel, return unchanged
            changeset

          {:ok, attendee} ->
            # Delete the attendee record
            Ash.destroy!(attendee, authorize?: false)

            # Decrement count
            Ash.Changeset.change_attribute(
              changeset,
              :rsvp_count,
              max(changeset.data.rsvp_count - 1, 0)
            )

          {:error, error} ->
            Ash.Changeset.add_error(changeset, error)
        end
      end
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

    # Read policies
    policy action(:read) do
      description "Users can read huddls they have access to"
      # Public huddls in public groups
      authorize_if Huddlz.Communities.Huddl.Checks.PublicHuddl
      # Any huddl in a group they're a member of
      authorize_if Huddlz.Communities.Huddl.Checks.GroupMember
    end

    policy action(:upcoming) do
      description "Users can view upcoming huddls they have access to"
      # Public huddls in public groups
      authorize_if Huddlz.Communities.Huddl.Checks.PublicHuddl
      # Any huddl in a group they're a member of
      authorize_if Huddlz.Communities.Huddl.Checks.GroupMember
    end

    policy action(:search) do
      description "Users can search huddls they have access to"
      # Public huddls in public groups
      authorize_if Huddlz.Communities.Huddl.Checks.PublicHuddl
      # Any huddl in a group they're a member of
      authorize_if Huddlz.Communities.Huddl.Checks.GroupMember
    end

    policy action(:by_group) do
      description "Users can view huddls by group if they have access"
      # Public huddls in public groups
      authorize_if Huddlz.Communities.Huddl.Checks.PublicHuddl
      # Any huddl in a group they're a member of
      authorize_if Huddlz.Communities.Huddl.Checks.GroupMember
    end

    policy action(:by_status) do
      description "Users can filter huddls by status"
      # Public huddls in public groups
      authorize_if Huddlz.Communities.Huddl.Checks.PublicHuddl
      # Any huddl in a group they're a member of
      authorize_if Huddlz.Communities.Huddl.Checks.GroupMember
    end

    # RSVP policies
    policy action(:rsvp) do
      description "Users can RSVP to huddls they have access to"
      # User must be RSVPing for themselves
      forbid_unless expr(^arg(:user_id) == ^actor(:id))
      # Public huddls in public groups
      authorize_if Huddlz.Communities.Huddl.Checks.PublicHuddl
      # Any huddl in a group they're a member of
      authorize_if Huddlz.Communities.Huddl.Checks.GroupMember
    end

    # Cancel RSVP policies
    policy action(:cancel_rsvp) do
      description "Users can cancel their own RSVPs"
      # User must be cancelling their own RSVP
      forbid_unless expr(^arg(:user_id) == ^actor(:id))
      # Public huddls in public groups
      authorize_if Huddlz.Communities.Huddl.Checks.PublicHuddl
      # Any huddl in a group they're a member of
      authorize_if Huddlz.Communities.Huddl.Checks.GroupMember
    end

    # Update policies
    policy action(:update) do
      description "Only group owners and organizers can update huddls"
      authorize_if Huddlz.Communities.Huddl.Checks.GroupOwnerOrOrganizer
    end

    # Delete policies
    policy action(:destroy) do
      description "Only group owners and organizers can delete huddls"
      authorize_if Huddlz.Communities.Huddl.Checks.GroupOwnerOrOrganizer
    end
  end

  changes do
    change fn changeset, _ ->
      # Only validate future start date on create
      if changeset.action == :create do
        case Ash.Changeset.get_attribute(changeset, :starts_at) do
          nil ->
            changeset

          starts_at ->
            if DateTime.compare(starts_at, DateTime.utc_now()) == :lt do
              Ash.Changeset.add_error(changeset,
                field: :starts_at,
                message: "must be in the future"
              )
            else
              changeset
            end
        end
      else
        changeset
      end
    end
  end

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

    attribute :rsvp_count, :integer do
      allow_nil? false
      default 0
    end

    attribute :thumbnail_url, :string do
      allow_nil? true
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

    has_many :attendees, Huddlz.Communities.HuddlAttendee do
      destination_attribute :huddl_id
    end
  end

  calculations do
    calculate :status, :atom do
      calculation fn records, _context ->
        now = DateTime.utc_now()

        Enum.map(records, fn record ->
          cond do
            DateTime.compare(record.starts_at, now) == :gt -> :upcoming
            DateTime.compare(record.ends_at, now) == :lt -> :completed
            true -> :in_progress
          end
        end)
      end
    end

    calculate :visible_virtual_link, :string do
      calculation Huddlz.Communities.Huddl.Calculations.VisibleVirtualLink
    end
  end

  identities do
    identity :unique_title_per_creator, [:creator_id, :title]
  end
end
