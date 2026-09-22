defmodule Huddlz.Communities.SocialConnection do
  @moduledoc """
  A group's link to one outside place where huddlz posts on its behalf: one
  Slack channel, one Discord channel. The group owns it. The owner connects,
  edits and removes it; organizers see it and can pause and resume it;
  members and the public see nothing. Only public groups have them.

  The webhook address the connection posts through is a secret: stored
  encrypted, never shown, never returned by the API. Each connection
  carries its own social schedule (the moments it posts each huddl at) and
  an optional opening line; scheduled posting itself lives elsewhere.
  """

  use Ash.Resource,
    otp_app: :huddlz,
    domain: Huddlz.Communities,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    notifiers: [Huddlz.Communities.ActivityLog],
    extensions: [AshGraphql.Resource, AshJsonApi.Resource]

  alias Huddlz.Communities.SocialConnection.{EncryptedString, Kind, Moment}

  @states [:posting, :paused, :needs_reconnecting]

  graphql do
    type :social_connection

    queries do
      list :social_connections, :for_group
    end

    mutations do
      action :send_social_test_post, :send_test_post
      create :connect_place, :connect
      update :reconnect_social_connection, :reconnect
      update :edit_social_connection, :edit
      update :pause_social_connection, :pause
      update :resume_social_connection, :resume
      destroy :remove_social_connection, :remove
    end
  end

  json_api do
    type "social_connection"

    routes do
      base "/social_connections"

      index :for_group, route: "/for_group"
      post :connect
      patch :edit
      patch :reconnect, route: "/:id/reconnect"
      patch :pause, route: "/:id/pause"
      patch :resume, route: "/:id/resume"
      route :post, "/:id/test_post", :send_test_post
      delete :remove
    end
  end

  postgres do
    table "social_connections"
    repo Huddlz.Repo

    references do
      reference :group, on_delete: :delete
      reference :connected_by, on_delete: :nilify
    end
  end

  actions do
    defaults [:read]

    create :connect do
      description """
      Connect a place for the group to post to. The owner does this through
      the platform's own consent screen, which hands back the webhook; the
      API takes a webhook address made by hand.
      """

      argument :group_id, :uuid do
        allow_nil? false
      end

      accept [
        :kind,
        :workspace_name,
        :channel_name,
        :webhook_url,
        :moments,
        :opening_line,
        :discord_guild_id,
        :discord_channel_id
      ]

      validate Huddlz.Communities.SocialConnection.Validations.GroupIsPublic
      validate Huddlz.Communities.SocialConnection.Validations.PlatformWebhook

      change set_attribute(:group_id, arg(:group_id))
      change relate_actor(:connected_by)
    end

    update :reconnect do
      description "Replace a place's credentials while keeping its social schedule and history"
      # The destination validation examines the existing kind and unwraps the
      # replacement credential, so it must run against the loaded record.
      require_atomic? false
      accept [:workspace_name, :channel_name, :discord_guild_id, :discord_channel_id]

      argument :webhook_url, EncryptedString do
        allow_nil? false
        sensitive? true
      end

      change set_attribute(:webhook_url, arg(:webhook_url))
      validate Huddlz.Communities.SocialConnection.Validations.GroupIsPublic
      validate Huddlz.Communities.SocialConnection.Validations.PlatformWebhook
      change set_attribute(:state, :posting)
    end

    update :edit do
      description "Change the social schedule and opening line"
      accept [:moments, :opening_line]
    end

    update :mark_needs_reconnecting do
      description "Record that the platform no longer accepts this connection"
      accept []
      change set_attribute(:state, :needs_reconnecting)
    end

    update :pause do
      description "Stop posting until resumed; nothing missed is sent later"
      accept []
      change set_attribute(:state, :paused)
    end

    update :resume do
      description "Post again from now on"
      accept []
      change set_attribute(:state, :posting)
    end

    destroy :remove do
      description "Drop the connection; reconnecting goes through the platform again"
    end

    action :send_test_post do
      description "Post a message to the place saying it is a test from huddlz"

      argument :id, :uuid do
        allow_nil? false
      end

      run Huddlz.Communities.SocialConnection.Actions.SendTestPost
    end

    read :for_group do
      description "The group's social connections, oldest first, for its owner and organizers"

      argument :group_id, :uuid do
        allow_nil? false
      end

      filter expr(group_id == ^arg(:group_id))
      prepare build(sort: [inserted_at: :asc], load: [:connected_by])
    end
  end

  policies do
    policy [action_type([:create, :update, :destroy]), actor_present()] do
      authorize_if Huddlz.Accounts.Checks.ConfirmedActor
    end

    policy action(:connect) do
      authorize_if Huddlz.Communities.GroupMember.Checks.GroupOwner
    end

    policy action([:edit, :reconnect, :remove, :mark_needs_reconnecting]) do
      authorize_if expr(group.owner_id == ^actor(:id))
    end

    policy action(:send_test_post) do
      forbid_unless Huddlz.Accounts.Checks.ConfirmedActor
      authorize_if Huddlz.Communities.SocialConnection.Checks.OwnsConnectionArgument
    end

    policy action([:pause, :resume]) do
      authorize_if expr(group.owner_id == ^actor(:id))

      authorize_if expr(
                     exists(
                       group.group_members,
                       user_id == ^actor(:id) and role == :organizer
                     )
                   )
    end

    policy action_type(:read) do
      authorize_if expr(group.owner_id == ^actor(:id))

      authorize_if expr(
                     exists(
                       group.group_members,
                       user_id == ^actor(:id) and role == :organizer
                     )
                   )
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :kind, Kind do
      allow_nil? false
      public? true
    end

    attribute :workspace_name, :string do
      description "The Slack workspace or Discord server"
      allow_nil? false
      public? true
      constraints max_length: 200
    end

    attribute :channel_name, :string do
      allow_nil? false
      public? true
      constraints max_length: 200
    end

    attribute :discord_guild_id, :string do
      public? true
      constraints match: ~r/\A[0-9]+\z/, max_length: 20
    end

    attribute :discord_channel_id, :string do
      public? true
      constraints match: ~r/\A[0-9]+\z/, max_length: 20
    end

    # The address posts go to. Never public: the API neither returns nor
    # filters on it, and the site never shows it.
    attribute :webhook_url, EncryptedString do
      allow_nil? false
      sensitive? true
    end

    attribute :moments, {:array, Moment} do
      description "The social schedule: the moments this connection posts each huddl at"
      allow_nil? false
      public? true
      default []
    end

    attribute :opening_line, :string do
      description "An optional first line for every post"
      public? true
      constraints max_length: 140, trim?: true, allow_empty?: false
    end

    attribute :state, :atom do
      allow_nil? false
      public? true
      default :posting
      constraints one_of: @states
    end

    create_timestamp :inserted_at, public?: true
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :group, Huddlz.Communities.Group do
      allow_nil? false
      public? true
    end

    # Who first connected it, kept as history; the group owns the connection.
    belongs_to :connected_by, Huddlz.Accounts.User do
      read_action :read_for_others
      attribute_public? true
    end
  end

  @doc "The non-secret Discord channel link, distinct from the posting credential."
  def destination_url(%__MODULE__{
        kind: :discord,
        discord_guild_id: guild,
        discord_channel_id: channel
      })
      when is_binary(guild) and is_binary(channel),
      do: "https://discord.com/channels/#{guild}/#{channel}"

  def destination_url(_connection), do: nil

  @doc "Every state a connection can be in."
  def states, do: @states

  @doc "The place as shown: \"Slack · #general\"."
  def place(%__MODULE__{kind: kind, channel_name: channel}),
    do: "#{Kind.label(kind)} · #{channel}"
end
