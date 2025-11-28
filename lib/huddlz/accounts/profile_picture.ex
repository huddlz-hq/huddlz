defmodule Huddlz.Accounts.ProfilePicture do
  @moduledoc """
  Profile picture resource for storing user avatars.

  The current profile picture for a user is determined by the most recent
  record by `inserted_at`. Old pictures remain in the database until cleaned
  up by a background job.
  """

  use Ash.Resource,
    otp_app: :huddlz,
    domain: Huddlz.Accounts,
    authorizers: [Ash.Policy.Authorizer],
    data_layer: AshPostgres.DataLayer

  postgres do
    table "profile_pictures"
    repo Huddlz.Repo

    custom_indexes do
      index [:user_id, :inserted_at]
    end
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      description "Upload a new profile picture for a user"
      primary? true
      accept [:filename, :content_type, :size_bytes, :storage_path, :user_id]
    end

    read :get_current_for_user do
      description "Get the current (most recent) profile picture for a user"
      get? true

      argument :user_id, :uuid do
        allow_nil? false
      end

      filter expr(user_id == ^arg(:user_id))
      prepare build(sort: [inserted_at: :desc], limit: 1)
    end

    read :list_for_user do
      description "Get all profile pictures for a user (for cleanup)"

      argument :user_id, :uuid do
        allow_nil? false
      end

      filter expr(user_id == ^arg(:user_id))
      prepare build(sort: [inserted_at: :desc])
    end
  end

  policies do
    bypass actor_attribute_equals(:role, :admin) do
      authorize_if always()
    end

    # Users can upload pictures for themselves
    policy action(:create) do
      description "Users can only upload profile pictures for themselves"
      authorize_if Huddlz.Accounts.ProfilePicture.Checks.IsOwnPicture
    end

    # Anyone can read profile pictures (they're public)
    policy action_type(:read) do
      authorize_if always()
    end

    # Users can destroy their own pictures
    policy action(:destroy) do
      description "Users can only delete their own profile pictures"
      authorize_if relates_to_actor_via(:user)
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :filename, :string do
      allow_nil? false
      public? true
      description "Original filename of the uploaded image"
    end

    attribute :content_type, :string do
      allow_nil? false
      public? true
      description "MIME type of the image (e.g., image/jpeg, image/png)"
    end

    attribute :size_bytes, :integer do
      allow_nil? false
      public? true
      description "File size in bytes"
    end

    attribute :storage_path, :string do
      allow_nil? false
      public? true
      description "Path to the file in the storage system (S3, local, etc.)"
    end

    create_timestamp :inserted_at
  end

  relationships do
    belongs_to :user, Huddlz.Accounts.User do
      attribute_type :uuid
      allow_nil? false
      public? true
    end
  end

  identities do
    identity :unique_storage_path, [:storage_path]
  end
end
