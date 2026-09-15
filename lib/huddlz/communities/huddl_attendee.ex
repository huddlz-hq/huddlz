defmodule Huddlz.Communities.HuddlAttendee do
  @moduledoc """
  Represents attendance/RSVP of users to huddlz.
  """

  use Ash.Resource,
    otp_app: :huddlz,
    domain: Huddlz.Communities,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    notifiers: [Huddlz.Communities.ActivityLog],
    extensions: [AshPaperTrail.Resource, AshJsonApi.Resource, AshGraphql.Resource]

  graphql do
    type :huddl_attendee

    queries do
      list :huddl_attendees, :by_huddl
      list :viewer_rsvps, :by_user
    end
  end

  json_api do
    type "huddl_attendee"

    default_fields [:waitlisted_at, :display_name, :picture_url]

    routes do
      base "/huddl_attendees"

      index :by_huddl, route: "/by_huddl"
      index :by_user, route: "/mine"
    end
  end

  paper_trail do
    change_tracking_mode :snapshot
    store_action_name? true
    reference_source? false
    sensitive_attributes :ignore
    ignore_attributes [:inserted_at, :updated_at]
    belongs_to_actor :actor, Huddlz.Accounts.User, domain: Huddlz.Accounts, on_delete: :nilify
    metadata :impersonation_id, :uuid
    metadata :impersonator_id, :uuid
    metadata :automatic?, :boolean
    version_extensions authorizers: [Ash.Policy.Authorizer]
    mixin {Huddlz.Audit.Version, :mixin, []}
  end

  postgres do
    table "huddl_attendees"
    repo Huddlz.Repo

    references do
      reference :huddl, on_delete: :delete
    end

    custom_indexes do
      index [:user_id]
    end
  end

  actions do
    defaults [:read, :destroy]

    create :rsvp do
      primary? true
      description "RSVP to a huddl"

      argument :huddl_id, :uuid do
        allow_nil? false
      end

      argument :user_id, :uuid do
        allow_nil? false
      end

      change set_attribute(:huddl_id, arg(:huddl_id))
      change set_attribute(:user_id, arg(:user_id))
    end

    create :join_waitlist do
      description "Join the waitlist for a full huddl"

      argument :huddl_id, :uuid do
        allow_nil? false
      end

      argument :user_id, :uuid do
        allow_nil? false
      end

      change set_attribute(:huddl_id, arg(:huddl_id))
      change set_attribute(:user_id, arg(:user_id))
      change set_attribute(:waitlisted_at, &DateTime.utc_now/0)
    end

    update :promote_from_waitlist do
      description "Clear waitlisted_at, moving the entry from waitlist to attending"

      change set_attribute(:waitlisted_at, nil)
    end

    destroy :cancel_rsvp do
      description "Cancel RSVP or leave waitlist for a huddl"
    end

    read :by_huddl do
      description "The people going to a huddl, in RSVP order"

      argument :huddl_id, :uuid do
        allow_nil? false
      end

      filter expr(huddl_id == ^arg(:huddl_id) and is_nil(waitlisted_at))
      prepare build(sort: [rsvped_at: :asc])
    end

    read :waitlist_for_huddl do
      description "Get all waitlist entries for a huddl, oldest first"

      argument :huddl_id, :uuid do
        allow_nil? false
      end

      filter expr(
               huddl_id == ^arg(:huddl_id) and not is_nil(waitlisted_at) and
                 is_nil(user.suspended_at)
             )

      prepare build(sort: [waitlisted_at: :asc])
    end

    read :by_user do
      description "Get all huddlz the current actor has RSVPed to"
      filter expr(user_id == ^actor(:id))
    end

    read :check_rsvp do
      description "Check if the current actor has a row (RSVP or waitlist) for a huddl"

      argument :huddl_id, :uuid do
        allow_nil? false
      end

      filter expr(huddl_id == ^arg(:huddl_id) and user_id == ^actor(:id))
    end

    read :notification_recipients do
      description "Resolve RSVP and waitlist recipients for system-driven huddl notifications"

      argument :huddl_ids, {:array, :uuid} do
        allow_nil? false
        constraints min_length: 1
      end

      filter expr(huddl_id in ^arg(:huddl_ids))
    end
  end

  policies do
    # Background maintenance retains its existing policies. A signed-in
    # actor must prove address ownership before mutating community data.
    policy [action_type([:create, :update, :destroy]), actor_present()] do
      authorize_if Huddlz.Accounts.Checks.ConfirmedActor
    end

    # Users can RSVP to huddlz they have access to
    policy action(:rsvp) do
      description "Allow users to RSVP to accessible huddlz"
      # User must be RSVPing for themselves
      forbid_unless expr(^arg(:user_id) == ^actor(:id))
      # And they must have access to view the huddl
      # The huddl access check will be done in the LiveView
      authorize_if always()
    end

    # Users can join a waitlist for huddlz they have access to
    policy action(:join_waitlist) do
      description "Allow users to join a waitlist for accessible huddlz"
      forbid_unless expr(^arg(:user_id) == ^actor(:id))
      authorize_if always()
    end

    # Promote action runs system-driven (cancellations, capacity bumps).
    policy action(:promote_from_waitlist) do
      description "Promotion is invoked by other actions, not user-facing"
      authorize_if always()
    end

    # Users can cancel their own RSVPs
    policy action(:cancel_rsvp) do
      description "Allow users to cancel their own RSVPs"
      authorize_if relates_to_actor_via(:user)
    end

    # Allow the default read action (used by aggregates like rsvp_count)
    policy action(:read) do
      description "Participation in public groups or groups the actor belongs to"
      authorize_if expr(huddl.group.is_public == true and is_nil(huddl.group.archived_at))
      authorize_if relates_to_actor_via([:huddl, :group, :members])
      authorize_if relates_to_actor_via(:user)
    end

    # You see who's going only if you're going: an RSVP or a waitlist spot on
    # this huddl. Organizers get no exception here; the organize workspace has
    # its own record of what people did.
    policy action(:by_huddl) do
      authorize_if Huddlz.Communities.HuddlAttendee.Checks.IsAttendee
      forbid_if always()
    end

    # Group owners and organizers can see the waitlist for huddlz they organize.
    # The waitlist is an operational view (managing capacity), so we restrict to
    # organizers rather than allowing fellow attendees as :by_huddl does.
    policy action(:waitlist_for_huddl) do
      authorize_if Huddlz.Communities.HuddlAttendee.Checks.IsGroupOwnerOrOrganizer
      forbid_if always()
    end

    # Users can see their own RSVPs
    policy action(:by_user) do
      authorize_if actor_present()
    end

    # Users can check their own RSVP status
    policy action(:check_rsvp) do
      authorize_if actor_present()
    end
  end

  attributes do
    uuid_primary_key :id

    create_timestamp :rsvped_at

    attribute :waitlisted_at, :utc_datetime_usec do
      allow_nil? true
      public? true
      description "When set, this row is a waitlist entry; when nil, an active RSVP."
    end
  end

  relationships do
    belongs_to :huddl, Huddlz.Communities.Huddl do
      attribute_type :uuid
      allow_nil? false
      primary_key? false
    end

    belongs_to :user, Huddlz.Accounts.User do
      read_action :read_for_others
      attribute_type :uuid
      allow_nil? false
      primary_key? false
    end
  end

  calculations do
    calculate :waitlist_position,
              :integer,
              Huddlz.Communities.HuddlAttendee.Calculations.WaitlistPosition

    calculate :account_suspended, :boolean, expr(not is_nil(user.suspended_at)) do
      description "True while the person's account is suspended"
    end

    calculate :display_name,
              :string,
              expr(
                if is_nil(user.suspended_at) do
                  user.display_name
                else
                  "Suspended account"
                end
              ) do
      public? true
      description "The display name of the person going, or a neutral label once suspended"
    end

    calculate :picture_url, :string, Huddlz.Communities.HuddlAttendee.Calculations.PictureUrl do
      public? true
      description "The person's current profile picture, when they have one"
    end
  end

  identities do
    identity :unique_huddl_user, [:huddl_id, :user_id]
  end
end
