defmodule Huddlz.Communities.Huddl do
  @moduledoc """
  A huddl represents an event or gathering within the Huddlz platform.
  """

  use Ash.Resource,
    otp_app: :huddlz,
    domain: Huddlz.Communities,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "huddlz"
    repo Huddlz.Repo
  end

  actions do
    defaults [:read, :destroy]

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
    end

    read :upcoming do
      filter expr(starts_at > ^DateTime.utc_now())
    end

    read :search do
      argument :query, :ci_string do
        allow_nil? true
      end

      filter expr(
               is_nil(^arg(:query)) or contains(title, ^arg(:query)) or
                 contains(description, ^arg(:query))
             )
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
  end

  calculations do
    calculate :status, :atom do
      calculation fn records, _context ->
        now = DateTime.utc_now()

        Enum.map(records, fn record ->
          cond do
            record.starts_at > now -> :upcoming
            record.ends_at < now -> :completed
            true -> :in_progress
          end
        end)
      end
    end
  end

  identities do
    identity :unique_title_per_creator, [:creator_id, :title]
  end
end
