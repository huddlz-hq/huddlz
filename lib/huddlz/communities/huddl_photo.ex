defmodule Huddlz.Communities.HuddlPhoto do
  @moduledoc """
  A photo shared to a huddl's post-huddl gallery by its creator or a
  confirmed attendee, once the huddl has ended.
  """

  alias Huddlz.Storage.HuddlPhotos

  use Ash.Resource,
    otp_app: :huddlz,
    domain: Huddlz.Communities,
    authorizers: [Ash.Policy.Authorizer],
    data_layer: AshPostgres.DataLayer

  postgres do
    table "huddl_photos"
    repo Huddlz.Repo

    references do
      reference :huddl, on_delete: :delete
      reference :uploader, on_delete: :delete
    end

    custom_indexes do
      index [:huddl_id, :inserted_at]
    end
  end

  actions do
    defaults [:read]

    create :create do
      description "Add a photo to a huddl's post-huddl gallery"
      primary? true
      accept [:filename, :content_type, :size_bytes, :storage_path, :thumbnail_path, :huddl_id]

      change relate_actor(:uploader)
    end

    read :list_for_huddl do
      description "Get all photos for a huddl, newest first"

      argument :huddl_id, :uuid do
        allow_nil? false
      end

      filter expr(huddl_id == ^arg(:huddl_id))
      prepare build(sort: [inserted_at: :desc])
    end

    destroy :destroy do
      description "Delete a photo and remove it from storage"
      primary? true
      require_atomic? false

      change fn changeset, _context ->
        Ash.Changeset.before_action(changeset, fn changeset ->
          record = changeset.data

          case HuddlPhotos.delete(record.storage_path) do
            :ok -> :ok
            {:error, reason} -> raise "Storage delete failed: #{inspect(reason)}"
          end

          if record.thumbnail_path do
            HuddlPhotos.delete(record.thumbnail_path)
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

    policy action(:create) do
      description "Only the huddl's creator or a confirmed attendee can upload photos, after the huddl has ended"

      forbid_unless expr(
                      huddl.lifecycle_state == :completed or
                        (huddl.lifecycle_state == :published and huddl.ends_at < now())
                    )

      authorize_if expr(huddl.creator_id == ^actor(:id))

      authorize_if expr(
                     exists(
                       huddl.attendees,
                       user_id == ^actor(:id) and is_nil(waitlisted_at)
                     )
                   )
    end

    policy action_type(:read) do
      description "Only the huddl's creator or a confirmed attendee can view photos, after the huddl has ended"

      forbid_unless expr(
                      huddl.lifecycle_state == :completed or
                        (huddl.lifecycle_state == :published and huddl.ends_at < now())
                    )

      authorize_if expr(huddl.creator_id == ^actor(:id))

      authorize_if expr(
                     exists(
                       huddl.attendees,
                       user_id == ^actor(:id) and is_nil(waitlisted_at)
                     )
                   )
    end

    policy action(:destroy) do
      description "A photo's uploader or the huddl's creator can delete it"
      authorize_if expr(uploader_id == ^actor(:id))
      authorize_if expr(huddl.creator_id == ^actor(:id))
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :filename, :string do
      allow_nil? false
      public? true
      description "Original filename of the uploaded photo"
    end

    attribute :content_type, :string do
      allow_nil? false
      public? true
      description "MIME type of the photo (e.g., image/jpeg, image/png)"
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
      description "Path to the resized grid thumbnail (256x256) in storage"
    end

    create_timestamp :inserted_at
  end

  relationships do
    belongs_to :huddl, Huddlz.Communities.Huddl do
      attribute_type :uuid
      allow_nil? false
      public? true
    end

    belongs_to :uploader, Huddlz.Accounts.User do
      attribute_type :uuid
      allow_nil? false
      public? true
    end
  end

  identities do
    identity :unique_storage_path, [:storage_path]
  end
end
