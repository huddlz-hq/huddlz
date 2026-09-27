defmodule Huddlz.Communities.SocialPost do
  @moduledoc """
  One message about one huddl to one social connection. Posts are planned
  from the connection's social schedule as huddlz are published, edited and
  cancelled (see `Huddlz.Social.Schedule`), sent once when their moment
  comes, and kept with their result.

  A post goes out through its own Oban job and is sent at most once: only a
  scheduled post is delivered, and delivering it records the result. A
  moment the connection could not post at (paused, needing reconnecting,
  or the huddl no longer public) is skipped, never sent late.
  """

  use Ash.Resource,
    otp_app: :huddlz,
    domain: Huddlz.Communities,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshOban, AshGraphql.Resource, AshJsonApi.Resource]

  alias Huddlz.Communities.SocialPost.Occasion

  @states [:scheduled, :sent, :not_sent, :skipped]

  graphql do
    type :social_post

    queries do
      list :upcoming_social_posts, :upcoming_for_group
      list :recent_social_posts, :recent_for_group
    end
  end

  json_api do
    type "social_post"

    routes do
      base "/social_posts"

      index :upcoming_for_group, route: "/upcoming"
      index :recent_for_group, route: "/recent"
    end
  end

  oban do
    triggers do
      trigger :deliver do
        action :deliver
        read_action :due
        worker_read_action :read
        # Checked again when the job runs: a post whose huddl moved later
        # after its job was queued waits for its new time.
        where expr(state == :scheduled and due_at <= now())
        scheduler_cron "* * * * *"
        queue :social
        max_attempts 4
        on_error :give_up
        worker_module_name Huddlz.Social.Workers.DeliverPost
        scheduler_module_name Huddlz.Social.Workers.DeliverPostScheduler
      end
    end
  end

  postgres do
    table "social_posts"
    repo Huddlz.Repo

    references do
      reference :social_connection, on_delete: :delete
      reference :huddl, on_delete: :delete
    end

    identity_wheres_to_sql unique_occasion: "occasion <> 'moved'"
  end

  actions do
    defaults [:read]

    create :schedule do
      description "Plan a post; an existing post for the same moment moves to the new time while still scheduled"
      accept [:social_connection_id, :huddl_id, :occasion, :due_at, :previous_starts_at]

      upsert? true
      upsert_identity :unique_occasion
      upsert_fields [:due_at]
      upsert_condition expr(state == :scheduled)
      return_skipped_upsert? true
    end

    destroy :drop do
      description "Drop a post that has not gone out"
    end

    read :upcoming_for_group do
      description """
      The group's next posts, soonest first, on connections that are posting.
      Times are UTC; each huddl carries the time zone they are read in.
      """

      argument :group_id, :uuid do
        allow_nil? false
      end

      filter expr(
               social_connection.group_id == ^arg(:group_id) and state == :scheduled and
                 due_at > now() and social_connection.state == :posting
             )

      prepare build(
                sort: [due_at: :asc],
                limit: 50,
                load: [:social_connection, huddl: [:group]]
              )
    end

    read :recent_for_group do
      description "The group's posts that went out or could not be sent, latest first"

      argument :group_id, :uuid do
        allow_nil? false
      end

      filter expr(social_connection.group_id == ^arg(:group_id) and state in [:sent, :not_sent])

      prepare build(
                sort: [due_at: :desc],
                limit: 20,
                load: [:social_connection, huddl: [:group]]
              )
    end

    read :due do
      description "Scheduled posts whose moment has come"
      pagination keyset?: true, required?: false, default_limit: 100
      filter expr(state == :scheduled and due_at <= now())
    end

    update :deliver do
      description "Send the post, or skip it if its connection or huddl can no longer post it"
      require_atomic? false
      accept []
      change Huddlz.Social.Changes.Deliver
    end

    update :skip do
      description "Record that the post's moment passed without it going out"
      accept []
      change set_attribute(:state, :skipped)
    end

    update :give_up do
      description "Record that the post could not be sent after its retries"
      accept []
      change set_attribute(:state, :not_sent)
    end
  end

  policies do
    bypass AshOban.Checks.AshObanInteraction do
      authorize_if always()
    end

    policy action_type(:read) do
      authorize_if expr(social_connection.group.owner_id == ^actor(:id))

      authorize_if expr(
                     exists(
                       social_connection.group.group_members,
                       user_id == ^actor(:id) and role == :organizer
                     )
                   )
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :occasion, Occasion do
      allow_nil? false
      public? true
    end

    attribute :due_at, :utc_datetime do
      description "When the post goes out"
      allow_nil? false
      public? true
    end

    attribute :state, :atom do
      allow_nil? false
      public? true
      default :scheduled
      constraints one_of: @states
    end

    attribute :sent_at, :utc_datetime_usec do
      public? true
    end

    attribute :previous_starts_at, :utc_datetime do
      description "For a moved huddl's follow-up, when it used to start"
      public? true
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :social_connection, Huddlz.Communities.SocialConnection do
      allow_nil? false
      public? true
    end

    belongs_to :huddl, Huddlz.Communities.Huddl do
      allow_nil? false
      public? true
    end
  end

  identities do
    identity :unique_occasion, [:social_connection_id, :huddl_id, :occasion] do
      where expr(occasion != :moved)
    end
  end

  @doc "Every state a post can be in."
  def states, do: @states
end
