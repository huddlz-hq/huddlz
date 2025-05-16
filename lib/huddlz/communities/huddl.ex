defmodule Huddlz.Communities.Huddl do
  use Ash.Resource,
    otp_app: :huddlz,
    domain: Huddlz.Communities,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "huddlz"
    repo Huddlz.Repo
  end

  actions do
    defaults [:create, :read, :update, :destroy]

    read :by_status do
      argument :status, :string do
        allow_nil? false
      end

      filter expr(status == ^arg(:status))
    end

    read :upcoming do
      filter expr(status == "upcoming" and starts_at > ^DateTime.utc_now())
    end

    read :search do
      argument :query, :string do
        allow_nil? true
      end

      filter expr(
               is_nil(^arg(:query)) or like(title, ^"%\#{arg(:query)}%") or
                 like(description, ^"%\#{arg(:query)}%")
             )
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
      allow_nil? true
    end

    attribute :thumbnail_url, :string do
      allow_nil? true
    end

    attribute :status, :string do
      allow_nil? false
      default "upcoming"
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :host, Huddlz.Accounts.User do
      attribute_type :uuid
      allow_nil? false
      primary_key? false
    end
  end

  identities do
    identity :unique_title_per_host, [:host_id, :title]
  end
end
