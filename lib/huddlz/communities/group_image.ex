defmodule Huddlz.Communities.GroupImage do
  @moduledoc """
  Group image resource for storing group banners/cover images.

  The current image for a group is determined by the most recent
  record by `inserted_at`. Old images remain in the database until cleaned
  up by a background job.
  """

  alias Huddlz.Storage.GroupImages

  use Ash.Resource,
    otp_app: :huddlz,
    domain: Huddlz.Communities,
    authorizers: [Ash.Policy.Authorizer],
    data_layer: AshPostgres.DataLayer,
    extensions: [AshOban]

  postgres do
    table "group_images"
    repo Huddlz.Repo

    custom_indexes do
      index [:group_id, :inserted_at]
    end
  end

  oban do
    triggers do
      trigger :cleanup_storage do
        action :hard_delete
        # No scheduler - triggered immediately via run_oban_trigger
        scheduler_cron false
        queue :group_image_cleanup
        # Retry with exponential backoff (max_attempts defaults to 20)
        backoff :exponential
        log_final_error? true
        worker_module_name Huddlz.Workers.GroupImageCleanup
      end

      trigger :cleanup_orphaned_images do
        action :cleanup_orphaned
        # Run every hour to clean up pending images older than 24 hours
        scheduler_cron "0 * * * *"
        queue :group_image_cleanup
        read_action :orphaned_pending
        worker_module_name Huddlz.Workers.GroupImageOrphanedCleanup
        scheduler_module_name Huddlz.Workers.GroupImageOrphanedCleanupScheduler
      end
    end
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      description "Upload a new image for a group"
      primary? true
      accept [:filename, :content_type, :size_bytes, :storage_path, :thumbnail_path, :group_id]
    end

    create :create_pending do
      description "Create a pending image during eager upload (group_id = nil)"
      accept [:filename, :content_type, :size_bytes, :storage_path, :thumbnail_path]
      # group_id intentionally not accepted - stays nil for pending images
    end

    read :get_current_for_group do
      description "Get the current (most recent) image for a group"
      get? true

      argument :group_id, :uuid do
        allow_nil? false
      end

      filter expr(group_id == ^arg(:group_id) and is_nil(deleted_at))
      prepare build(sort: [inserted_at: :desc], limit: 1)
    end

    read :list_for_group do
      description "Get all non-deleted images for a group"

      argument :group_id, :uuid do
        allow_nil? false
      end

      filter expr(group_id == ^arg(:group_id) and is_nil(deleted_at))
      prepare build(sort: [inserted_at: :desc])
    end

    update :soft_delete do
      description "Soft-delete a group image and trigger cleanup job"
      accept []
      change set_attribute(:deleted_at, &DateTime.utc_now/0)
      change run_oban_trigger(:cleanup_storage)
    end

    update :assign_to_group do
      description "Assign a pending image to a group"

      argument :group_id, :uuid do
        allow_nil? false
      end

      validate attributes_absent(:group_id),
        message: "can only assign unassigned images"

      change set_attribute(:group_id, arg(:group_id))
    end

    read :orphaned_pending do
      description "Find pending images (no group_id) older than 24 hours"
      filter expr(is_nil(group_id) and inserted_at < ago(24, :hour))
      pagination keyset?: true
    end

    destroy :cleanup_orphaned do
      description "Delete orphaned pending image and its storage files"
      require_atomic? false

      change fn changeset, _context ->
        Ash.Changeset.before_action(changeset, fn changeset ->
          record = changeset.data

          # Delete original
          case GroupImages.delete(record.storage_path) do
            :ok -> :ok
            {:error, reason} -> raise "Storage delete failed: #{inspect(reason)}"
          end

          # Delete thumbnail if exists
          if record.thumbnail_path do
            GroupImages.delete(record.thumbnail_path)
          end

          changeset
        end)
      end
    end

    destroy :hard_delete do
      description "Hard-delete a group image and remove from storage"
      require_atomic? false

      change fn changeset, _context ->
        Ash.Changeset.before_action(changeset, fn changeset ->
          record = changeset.data

          # Delete original
          case GroupImages.delete(record.storage_path) do
            :ok -> :ok
            {:error, reason} -> raise "Storage delete failed: #{inspect(reason)}"
          end

          # Delete thumbnail (if exists) - ignore errors for orphaned thumbnails
          if record.thumbnail_path do
            GroupImages.delete(record.thumbnail_path)
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

    # Group owners can upload images for their groups
    # Note: create needs custom check since relationship isn't loaded yet
    policy action(:create) do
      description "Only group owners can upload images for their groups"
      authorize_if Huddlz.Communities.GroupImage.Checks.IsGroupOwner
    end

    # Any authenticated user can create pending images (no group yet)
    policy action(:create_pending) do
      description "Authenticated users can create pending images"
      authorize_if actor_present()
    end

    # Group owners can assign pending images to their groups
    policy action(:assign_to_group) do
      description "Only group owners can assign images to their groups"
      authorize_if Huddlz.Communities.GroupImage.Checks.IsGroupOwner
    end

    # Cleanup runs without actor (Oban job)
    policy action(:cleanup_orphaned) do
      description "Orphan cleanup is called by background jobs"
      authorize_if always()
    end

    # Read orphaned pending doesn't need authorization - used by Oban
    policy action(:orphaned_pending) do
      description "Read orphaned pending images for cleanup"
      authorize_if always()
    end

    # Anyone can read group images (they're public)
    policy action_type(:read) do
      authorize_if always()
    end

    # Group owners can destroy their group's images
    policy action(:destroy) do
      description "Only group owners can delete their group's images"
      authorize_if relates_to_actor_via([:group, :owner])
    end

    # Group owners can soft-delete their group's images
    policy action(:soft_delete) do
      description "Only group owners can soft-delete their group's images"
      authorize_if relates_to_actor_via([:group, :owner])
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
      description "Path to the resized thumbnail (1280x720) in storage"
    end

    create_timestamp :inserted_at

    attribute :deleted_at, :utc_datetime_usec do
      allow_nil? true
      public? false
      description "Timestamp when the image was soft-deleted"
    end
  end

  relationships do
    belongs_to :group, Huddlz.Communities.Group do
      attribute_type :uuid
      # Allow nil for pending images (not yet assigned to a group)
      allow_nil? true
      public? true
    end
  end

  identities do
    identity :unique_storage_path, [:storage_path]
  end
end
