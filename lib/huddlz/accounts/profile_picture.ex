defmodule Huddlz.Accounts.ProfilePicture do
  @moduledoc """
  Profile picture resource for storing user avatars.

  The current profile picture for a user is determined by the most recent
  record by `inserted_at`. Old pictures remain in the database until cleaned
  up by a background job.
  """

  alias Huddlz.Storage.ProfilePictures

  use Ash.Resource,
    otp_app: :huddlz,
    domain: Huddlz.Accounts,
    authorizers: [Ash.Policy.Authorizer],
    data_layer: AshPostgres.DataLayer,
    extensions: [AshOban]

  postgres do
    table "profile_pictures"
    repo Huddlz.Repo

    custom_indexes do
      index [:user_id, :inserted_at]
    end
  end

  oban do
    triggers do
      trigger :cleanup_storage do
        action :hard_delete
        # No scheduler - triggered immediately via run_oban_trigger
        scheduler_cron false
        queue :profile_picture_cleanup
        # Retry with exponential backoff (max_attempts defaults to 20)
        backoff :exponential
        log_final_error? true
        worker_module_name Huddlz.Workers.ProfilePictureCleanup
      end
    end
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      description "Upload a new profile picture for a user"
      primary? true
      accept [:filename, :content_type, :size_bytes, :storage_path, :thumbnail_path, :user_id]
    end

    read :get_current_for_user do
      description "Get the current (most recent) profile picture for a user"
      get? true

      argument :user_id, :uuid do
        allow_nil? false
      end

      filter expr(user_id == ^arg(:user_id) and is_nil(deleted_at))
      prepare build(sort: [inserted_at: :desc], limit: 1)
    end

    read :list_for_user do
      description "Get all non-deleted profile pictures for a user"

      argument :user_id, :uuid do
        allow_nil? false
      end

      filter expr(user_id == ^arg(:user_id) and is_nil(deleted_at))
      prepare build(sort: [inserted_at: :desc])
    end

    update :soft_delete do
      description "Soft-delete a profile picture and trigger cleanup job"
      accept []
      change set_attribute(:deleted_at, &DateTime.utc_now/0)
      change run_oban_trigger(:cleanup_storage)
    end

    destroy :hard_delete do
      description "Hard-delete a profile picture and remove from storage"
      require_atomic? false

      change fn changeset, _context ->
        Ash.Changeset.before_action(changeset, fn changeset ->
          record = changeset.data

          # Delete original
          case ProfilePictures.delete(record.storage_path) do
            :ok -> :ok
            {:error, reason} -> raise "Storage delete failed: #{inspect(reason)}"
          end

          # Delete thumbnail (if exists) - ignore errors for orphaned thumbnails
          if record.thumbnail_path do
            ProfilePictures.delete(record.thumbnail_path)
          end

          changeset
        end)
      end
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

    # Users can soft-delete their own pictures
    policy action(:soft_delete) do
      description "Users can only soft-delete their own profile pictures"
      authorize_if relates_to_actor_via(:user)
    end

    # Hard delete is only called by Oban workers (no actor)
    policy action(:hard_delete) do
      description "Hard delete is called by background jobs"
      authorize_if always()
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
      description "Path to the original file in the storage system (S3, local, etc.)"
    end

    attribute :thumbnail_path, :string do
      allow_nil? true
      public? true
      description "Path to the resized thumbnail in storage"
    end

    create_timestamp :inserted_at

    attribute :deleted_at, :utc_datetime_usec do
      allow_nil? true
      public? false
      description "Timestamp when the picture was soft-deleted"
    end
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
