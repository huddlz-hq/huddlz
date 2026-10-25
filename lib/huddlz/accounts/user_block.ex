defmodule Huddlz.Accounts.UserBlock do
  @moduledoc """
  A person's choice to stop seeing huddlz someone else organizes. Today a
  block is made from a huddl the person can see, and it blocks that
  huddl's organizer: their huddlz leave the person's discovery and group
  lists on every app. Huddlz the person already RSVPed to stay on their
  calendar, and an open link still works.

  Blocking is private. The blocked person is not told and can still see
  everything they could before. Only the person who blocked reads their
  blocks, by the blocked person's display name, and can remove them.
  """

  use Ash.Resource,
    otp_app: :huddlz,
    domain: Huddlz.Accounts,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshJsonApi.Resource]

  alias Huddlz.Accounts.User

  json_api do
    type "user_block"

    default_fields [:id, :blocked_user_name, :inserted_at]

    routes do
      base "/blocks"

      index :mine
      post :block_organizer, route: "/organizer"
      delete :unblock
    end
  end

  postgres do
    table "user_blocks"
    repo Huddlz.Repo

    references do
      reference :blocker, on_delete: :delete
      reference :blocked_user, on_delete: :delete
    end

    custom_indexes do
      index [:blocked_user_id]
    end
  end

  actions do
    defaults [:read]

    read :mine do
      description "The people the actor has blocked, most recent first"
      filter expr(blocker_id == ^actor(:id))
      prepare build(sort: [inserted_at: :desc], load: [:blocked_user_name])
    end

    create :block_organizer do
      description """
      Block the organizer of a huddl the actor can see. Blocking someone
      already blocked changes nothing.
      """

      accept []

      argument :huddl_id, :uuid do
        description "The huddl whose organizer to block"
        allow_nil? false
      end

      change Huddlz.Accounts.UserBlock.Changes.BlockHuddlOrganizer
      change relate_actor(:blocker, allow_nil?: true)

      upsert? true
      upsert_identity :one_per_person
      upsert_fields [:blocker_id]
    end

    destroy :unblock do
      description "Remove a block; the person's huddlz show up again"
      primary? true
    end
  end

  policies do
    policy action(:block_organizer) do
      description "Anyone signed in may block an organizer they can see"
      authorize_if actor_present()
    end

    policy action_type([:read, :destroy]) do
      description "People see and remove only their own blocks"
      authorize_if expr(blocker_id == ^actor(:id))
    end
  end

  attributes do
    uuid_primary_key :id

    create_timestamp :inserted_at do
      public? true
    end
  end

  relationships do
    belongs_to :blocker, User do
      description "Who chose to block"
      allow_nil? false
    end

    belongs_to :blocked_user, User do
      description "The person whose huddlz are hidden; never part of the API shape"
      allow_nil? false
    end
  end

  calculations do
    calculate :blocked_user_name,
              :string,
              expr(
                if is_nil(blocked_user.suspended_at) do
                  blocked_user.display_name
                else
                  "Suspended account"
                end
              ) do
      public? true
      description "The blocked person's display name, or a neutral label once suspended"
    end
  end

  identities do
    identity :one_per_person, [:blocker_id, :blocked_user_id]
  end
end
