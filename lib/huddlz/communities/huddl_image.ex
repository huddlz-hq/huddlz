defmodule Huddlz.Communities.HuddlImage do
  @moduledoc """
  Huddl image resource for storing huddl banners/cover images.

  The current image for a huddl is determined by the most recent
  record by `inserted_at`. Old images remain in the database until cleaned
  up by a background job.
  """

  alias Huddlz.Storage.HuddlImages

  use Ash.Resource,
    otp_app: :huddlz,
    domain: Huddlz.Communities,
    authorizers: [Ash.Policy.Authorizer],
    data_layer: AshPostgres.DataLayer,
    extensions: [AshOban]

  postgres do
    table "huddl_images"
    repo Huddlz.Repo

    custom_indexes do
      index [:huddl_id, :inserted_at]
    end
  end

  oban do
    triggers do
      trigger :cleanup_storage do
        action :hard_delete
        # No scheduler - triggered immediately via run_oban_trigger
        scheduler_cron false
        queue :huddl_image_cleanup
        # Retry with exponential backoff (max_attempts defaults to 20)
        backoff :exponential
        log_final_error? true
        worker_module_name Huddlz.Workers.HuddlImageCleanup
      end

      trigger :cleanup_orphaned_images do
        action :cleanup_orphaned
        # Run every hour to clean up pending images older than 24 hours
        scheduler_cron "0 * * * *"
        queue :huddl_image_cleanup
        read_action :orphaned_pending
        worker_module_name Huddlz.Workers.HuddlImageOrphanedCleanup
        scheduler_module_name Huddlz.Workers.HuddlImageOrphanedCleanupScheduler
      end
    end
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      description "Upload a new image for a huddl"
      primary? true
      accept [:filename, :content_type, :size_bytes, :storage_path, :thumbnail_path, :huddl_id]
    end

    create :create_pending do
      description "Create a pending image during eager upload (huddl_id = nil)"
      accept [:filename, :content_type, :size_bytes, :storage_path, :thumbnail_path]

      # group_id is required for authorization but not stored
      argument :group_id, :uuid do
        allow_nil? false
        description "Group ID for authorization - actor must be a member"
      end
    end

    read :get_current_for_huddl do
      description "Get the current (most recent) image for a huddl"
      get? true

      argument :huddl_id, :uuid do
        allow_nil? false
      end

      filter expr(huddl_id == ^arg(:huddl_id) and is_nil(deleted_at))
      prepare build(sort: [inserted_at: :desc], limit: 1)
    end

    read :list_for_huddl do
      description "Get all non-deleted images for a huddl"

      argument :huddl_id, :uuid do
        allow_nil? false
      end

      filter expr(huddl_id == ^arg(:huddl_id) and is_nil(deleted_at))
      prepare build(sort: [inserted_at: :desc])
    end

    update :soft_delete do
      description "Soft-delete a huddl image and trigger cleanup job"
      accept []
      change set_attribute(:deleted_at, &DateTime.utc_now/0)
      change run_oban_trigger(:cleanup_storage)
    end

    update :assign_to_huddl do
      description "Assign a pending image to a huddl"

      argument :huddl_id, :uuid do
        allow_nil? false
      end

      validate attributes_absent(:huddl_id),
        message: "can only assign unassigned images"

      change set_attribute(:huddl_id, arg(:huddl_id))
    end

    read :orphaned_pending do
      description "Find pending images (no huddl_id) older than 24 hours"
      filter expr(is_nil(huddl_id) and inserted_at < ago(24, :hour))
      pagination keyset?: true
    end

    destroy :cleanup_orphaned do
      description "Delete orphaned pending image and its storage files"
      require_atomic? false

      change fn changeset, _context ->
        Ash.Changeset.before_action(changeset, fn changeset ->
          record = changeset.data

          # Delete original
          case HuddlImages.delete(record.storage_path) do
            :ok -> :ok
            {:error, reason} -> raise "Storage delete failed: #{inspect(reason)}"
          end

          # Delete thumbnail if exists
          if record.thumbnail_path do
            HuddlImages.delete(record.thumbnail_path)
          end

          changeset
        end)
      end
    end

    destroy :hard_delete do
      description "Hard-delete a huddl image and remove from storage"
      require_atomic? false

      change fn changeset, _context ->
        Ash.Changeset.before_action(changeset, fn changeset ->
          record = changeset.data

          # Delete original
          case HuddlImages.delete(record.storage_path) do
            :ok -> :ok
            {:error, reason} -> raise "Storage delete failed: #{inspect(reason)}"
          end

          # Delete thumbnail (if exists) - ignore errors for orphaned thumbnails
          if record.thumbnail_path do
            HuddlImages.delete(record.thumbnail_path)
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

    # Group owners/organizers can upload images for huddlz in their groups
    policy action(:create) do
      description "Only group owners/organizers can upload images for huddlz"
      authorize_if Huddlz.Communities.HuddlImage.Checks.IsHuddlGroupOwnerOrOrganizer
    end

    # Group members can create pending images (for huddlz they're creating)
    policy action(:create_pending) do
      description "Group members can create pending images"
      authorize_if Huddlz.Communities.HuddlImage.Checks.IsGroupMember
    end

    # Group owners/organizers can assign pending images to huddlz
    policy action(:assign_to_huddl) do
      description "Only group owners/organizers can assign images to huddlz"
      authorize_if Huddlz.Communities.HuddlImage.Checks.IsHuddlGroupOwnerOrOrganizer
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

    # Anyone can read huddl images (they're public)
    policy action_type(:read) do
      authorize_if always()
    end

    # Group owners/organizers can destroy their huddl's images
    policy action(:destroy) do
      description "Only group owners/organizers can delete huddl images"
      authorize_if Huddlz.Communities.HuddlImage.Checks.IsHuddlGroupOwnerOrOrganizer
    end

    # Group owners/organizers can soft-delete their huddl's images
    # For pending images (no huddl), any authenticated user can soft-delete their own
    policy action(:soft_delete) do
      description "Group owners/organizers can soft-delete huddl images; authenticated users can soft-delete pending images"
      # Allow if the image has no huddl (pending) and actor is present
      authorize_if expr(is_nil(huddl_id) and not is_nil(^actor(:id)))
      # Allow if the actor is owner/organizer of the huddl's group
      authorize_if Huddlz.Communities.HuddlImage.Checks.IsHuddlGroupOwnerOrOrganizer
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
    belongs_to :huddl, Huddlz.Communities.Huddl do
      attribute_type :uuid
      # Allow nil for pending images (not yet assigned to a huddl)
      allow_nil? true
      public? true
    end
  end

  identities do
    identity :unique_storage_path, [:storage_path]
  end
end
