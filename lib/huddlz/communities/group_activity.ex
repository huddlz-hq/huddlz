defmodule Huddlz.Communities.GroupActivity do
  @moduledoc """
  An append-only log of what happened in a group: someone joined or left,
  RSVPd, cancelled, joined a waitlist or got a spot from it, accepted an
  invitation; a social connection was connected, edited, paused, resumed
  or removed. Written by `Huddlz.Communities.ActivityLog` as those actions
  run, since cancelling an RSVP and leaving a group delete their rows and
  would otherwise leave no trace.

  Rows reference the person and the huddl rather than copying names, so
  renames stay correct. Only the group's owner and organizers can read the
  log; nothing else writes to it.
  """

  use Ash.Resource,
    otp_app: :huddlz,
    domain: Huddlz.Communities,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshGraphql.Resource]

  @kinds [
    :joined,
    :left,
    :accepted_invitation,
    :rsvped,
    :cancelled_rsvp,
    :waitlisted,
    :left_waitlist,
    :promoted,
    :connected_place,
    :edited_place,
    :paused_place,
    :resumed_place,
    :removed_place
  ]

  graphql do
    type :group_activity

    queries do
      list :group_activity, :for_group
    end
  end

  postgres do
    table "group_activities"
    repo Huddlz.Repo

    references do
      reference :group, on_delete: :delete
      reference :huddl, on_delete: :nilify
      reference :user, on_delete: :delete
    end

    custom_indexes do
      index [:group_id, :occurred_at]
    end
  end

  actions do
    defaults [:read]

    create :record do
      description "Append one entry. Internal: written by the activity log notifier."

      accept [
        :kind,
        :occurred_at,
        :group_id,
        :huddl_id,
        :user_id,
        :impersonation_id,
        :source,
        :detail
      ]
    end

    read :for_group do
      description "The group's activity, newest first, for its organizers"

      argument :group_id, :uuid do
        allow_nil? false
      end

      argument :limit, :integer do
        default 20
        constraints min: 1, max: 100
      end

      filter expr(group_id == ^arg(:group_id))

      prepare build(
                sort: [occurred_at: :desc, id: :desc],
                load: [:user, :huddl, :not_a_member_yet, :rsvped_first]
              )

      prepare Huddlz.Communities.GroupActivity.Preparations.LimitFromArgument
    end
  end

  policies do
    policy action(:for_group) do
      access_type :strict
      authorize_if Huddlz.Communities.GroupMember.Checks.GroupOwner
      authorize_if Huddlz.Communities.GroupMember.Checks.GroupOrganizer
    end

    policy action(:read) do
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

    attribute :kind, :atom do
      allow_nil? false
      public? true
      constraints one_of: @kinds
    end

    attribute :occurred_at, :utc_datetime_usec do
      allow_nil? false
      public? true
      default &DateTime.utc_now/0
    end

    # Set when an administrator was viewing huddlz as the person at the time.
    attribute :impersonation_id, :uuid

    # Where a self-join came from, kept here so it outlives the membership.
    # For the admin overview only: organizers reading the log never see it.
    attribute :source, Huddlz.Communities.JoinSource

    # What a social connection entry is about ("Slack · #general"), kept
    # here so it outlives the connection.
    attribute :detail, :string do
      public? true
      constraints max_length: 300
    end
  end

  relationships do
    belongs_to :group, Huddlz.Communities.Group do
      allow_nil? false
      public? true
    end

    belongs_to :huddl, Huddlz.Communities.Huddl do
      public? true
    end

    # The person stays out of the GraphQL type (User has no field policies);
    # the API gets their id.
    belongs_to :user, Huddlz.Accounts.User do
      read_action :read_for_others
      allow_nil? false
      attribute_public? true
    end
  end

  calculations do
    calculate :not_a_member_yet,
              :boolean,
              {Huddlz.Communities.GroupActivity.Calculations.DropInNote, note: :not_a_member_yet} do
      description "On an RSVP: the person is not currently a member of the group."
      public? true
    end

    calculate :rsvped_first,
              :string,
              {Huddlz.Communities.GroupActivity.Calculations.DropInNote, note: :rsvped_first} do
      description "On a join: the latest huddl of the group the person RSVPd to before it while not a member."
      public? true
    end
  end

  @doc "Every kind of entry the log records."
  def kinds, do: @kinds
end
