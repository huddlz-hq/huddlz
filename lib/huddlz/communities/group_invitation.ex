defmodule Huddlz.Communities.GroupInvitation do
  @moduledoc """
  An invitation for a registered person to join a private group.

  Invitations deliberately remain separate from `GroupMember`: membership is
  only created after the invited person accepts.
  """

  use Ash.Resource,
    otp_app: :huddlz,
    domain: Huddlz.Communities,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  alias Huddlz.Communities.GroupInvitation.Changes.Accept
  alias Huddlz.Communities.GroupInvitation.Changes.ExpirePrevious
  alias Huddlz.Communities.GroupInvitation.Changes.LockPending
  alias Huddlz.Communities.GroupInvitation.Changes.NotifyInvitee
  alias Huddlz.Communities.GroupInvitation.Changes.SetExpiration
  alias Huddlz.Communities.GroupInvitation.Checks.InviteeIsNotMember
  alias Huddlz.Communities.GroupInvitation.Validations.GroupIsPrivate
  alias Huddlz.Communities.GroupInvitation.Validations.PendingAndCurrent
  alias Huddlz.Communities.GroupMember.Checks.GroupOrganizer
  alias Huddlz.Communities.GroupMember.Checks.GroupOwner

  postgres do
    table "group_invitations"
    repo Huddlz.Repo

    references do
      reference :group, on_delete: :delete
      reference :invitee, on_delete: :delete
      reference :inviter, on_delete: :delete
    end

    custom_indexes do
      index [:group_id, :invitee_id],
        unique: true,
        where: "status = 'pending'",
        name: "group_invitations_unique_pending_index",
        message: "already has a pending invitation to this group",
        error_fields: [:invitee_id]

      index [:invitee_id, :status, :inserted_at]
      index [:group_id, :status, :inserted_at]
    end
  end

  actions do
    defaults [:read]

    create :invite do
      description "Invite a registered person to a private group."

      argument :group_id, :uuid, allow_nil?: false
      argument :invitee_id, :uuid, allow_nil?: false

      argument :role, :atom do
        allow_nil? false
        default :member
        constraints one_of: [:member, :organizer]
      end

      change ExpirePrevious
      change manage_relationship(:group_id, :group, type: :append)
      change manage_relationship(:invitee_id, :invitee, type: :append)
      change relate_actor(:inviter)
      change set_attribute(:role, arg(:role))
      change SetExpiration
      validate GroupIsPrivate
      validate InviteeIsNotMember
      change NotifyInvitee
    end

    read :mine do
      description "List invitations addressed to the current actor."
      filter expr(invitee_id == ^actor(:id))
      prepare build(sort: [inserted_at: :desc])
    end

    read :get_mine do
      description "Get one invitation addressed to the current actor."
      get? true

      argument :id, :uuid, allow_nil?: false
      filter expr(id == ^arg(:id) and invitee_id == ^actor(:id))
    end

    read :for_group do
      description "List invitations for a group the actor organizes."

      argument :group_id, :uuid, allow_nil?: false
      filter expr(group_id == ^arg(:group_id))
      prepare build(sort: [inserted_at: :desc])
    end

    read :pending_for_user do
      description "Pending, current invitations addressed to the actor — backs the Invites tab."

      filter expr(invitee_id == ^actor(:id) and status == :pending and expires_at > now())

      prepare build(sort: [inserted_at: :desc])

      prepare fn query, _context ->
        Ash.Query.after_action(query, fn _query, results ->
          {:ok, Ash.load!(results, [:group, :inviter], authorize?: false)}
        end)
      end

      pagination keyset?: true,
                 offset?: true,
                 countable: true,
                 required?: false,
                 default_limit: 20
    end

    update :accept do
      description "Accept a current pending invitation and grant membership once."
      accept []
      require_atomic? false

      validate PendingAndCurrent
      change {LockPending, expiration: :future}
      change Accept
    end

    update :decline do
      description "Decline a current pending invitation."
      accept []
      require_atomic? false

      validate PendingAndCurrent
      change {LockPending, expiration: :future}
      change set_attribute(:status, :declined)
      change set_attribute(:responded_at, &DateTime.utc_now/0)
    end

    update :revoke do
      description "Revoke a pending invitation before it is accepted."
      accept []
      require_atomic? false

      validate attribute_equals(:status, :pending) do
        message "is no longer pending"
      end

      change {LockPending, expiration: :future}
      change set_attribute(:status, :revoked)
      change set_attribute(:responded_at, &DateTime.utc_now/0)
    end

    update :expire do
      description "Record that a pending invitation has reached its expiration time."
      accept []
      require_atomic? false

      validate attribute_equals(:status, :pending) do
        message "is no longer pending"
      end

      validate compare(:expires_at, less_than_or_equal_to: &DateTime.utc_now/0) do
        message "has not expired"
      end

      change {LockPending, expiration: :past}
      change set_attribute(:status, :expired)
      change set_attribute(:responded_at, &DateTime.utc_now/0)
    end
  end

  policies do
    bypass actor_attribute_equals(:role, :admin) do
      authorize_if always()
    end

    policy action(:invite) do
      authorize_if GroupOwner
      forbid_if expr(^arg(:role) == :organizer)
      authorize_if GroupOrganizer
    end

    policy action([:mine, :get_mine, :pending_for_user]) do
      authorize_if actor_present()
    end

    policy action(:for_group) do
      authorize_if expr(group.owner_id == ^actor(:id))

      authorize_if expr(
                     exists(
                       group.group_members,
                       user_id == ^actor(:id) and role == :organizer
                     )
                   )
    end

    policy action([:accept, :decline]) do
      authorize_if expr(invitee_id == ^actor(:id))
    end

    policy action(:revoke) do
      authorize_if expr(group.owner_id == ^actor(:id))
      forbid_if expr(role == :organizer)

      authorize_if expr(
                     exists(
                       group.group_members,
                       user_id == ^actor(:id) and role == :organizer
                     )
                   )
    end

    policy action(:expire) do
      authorize_if expr(invitee_id == ^actor(:id))
      authorize_if expr(group.owner_id == ^actor(:id))

      authorize_if expr(
                     exists(
                       group.group_members,
                       user_id == ^actor(:id) and role == :organizer
                     )
                   )
    end

    policy action(:read) do
      authorize_if expr(invitee_id == ^actor(:id))
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

    attribute :role, :atom do
      allow_nil? false
      public? true
      default :member
      constraints one_of: [:member, :organizer]
    end

    attribute :status, :atom do
      allow_nil? false
      public? true
      default :pending
      constraints one_of: [:pending, :accepted, :declined, :revoked, :expired]
    end

    attribute :expires_at, :utc_datetime_usec do
      allow_nil? false
      public? true
    end

    attribute :responded_at, :utc_datetime_usec do
      allow_nil? true
      public? true
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :group, Huddlz.Communities.Group do
      attribute_type :uuid
      allow_nil? false
    end

    belongs_to :invitee, Huddlz.Accounts.User do
      attribute_type :uuid
      allow_nil? false
    end

    belongs_to :inviter, Huddlz.Accounts.User do
      attribute_type :uuid
      allow_nil? false
    end
  end
end
