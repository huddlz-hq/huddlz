defmodule Huddlz.Communities.HuddlAttendee do
  @moduledoc """
  Represents attendance/RSVP of users to huddlz.
  """

  use Ash.Resource,
    otp_app: :huddlz,
    domain: Huddlz.Communities,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "huddl_attendees"
    repo Huddlz.Repo
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

      change manage_relationship(:huddl_id, :huddl, type: :append)
      change manage_relationship(:user_id, :user, type: :append)
    end

    destroy :cancel_rsvp do
      description "Cancel RSVP to a huddl"
    end

    read :by_huddl do
      description "Get all attendees for a huddl"

      argument :huddl_id, :uuid do
        allow_nil? false
      end

      filter expr(huddl_id == ^arg(:huddl_id))
    end

    read :by_user do
      description "Get all huddlz a user has RSVPed to"

      argument :user_id, :uuid do
        allow_nil? false
      end

      filter expr(user_id == ^arg(:user_id))
    end

    read :check_rsvp do
      description "Check if a user has RSVPed to a huddl"

      argument :huddl_id, :uuid do
        allow_nil? false
      end

      argument :user_id, :uuid do
        allow_nil? false
      end

      filter expr(huddl_id == ^arg(:huddl_id) and user_id == ^arg(:user_id))
    end
  end

  policies do
    # Admin bypass - admins can do everything
    bypass actor_attribute_equals(:role, :admin) do
      authorize_if always()
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

    # Users can cancel their own RSVPs
    policy action(:cancel_rsvp) do
      description "Allow users to cancel their own RSVPs"
      authorize_if relates_to_actor_via(:user)
    end

    # Reading attendees follows same rules as viewing members
    # Only verified users or group members can see attendee lists
    policy action(:by_huddl) do
      # This will be checked at the LiveView level based on group membership
      authorize_if always()
    end

    # Users can see their own RSVPs
    policy action(:by_user) do
      authorize_if expr(^arg(:user_id) == ^actor(:id))
    end

    # Users can check their own RSVP status
    policy action(:check_rsvp) do
      authorize_if expr(^arg(:user_id) == ^actor(:id))
    end
  end

  attributes do
    uuid_primary_key :id

    create_timestamp :rsvped_at
  end

  relationships do
    belongs_to :huddl, Huddlz.Communities.Huddl do
      attribute_type :uuid
      allow_nil? false
      primary_key? false
    end

    belongs_to :user, Huddlz.Accounts.User do
      attribute_type :uuid
      allow_nil? false
      primary_key? false
    end
  end

  identities do
    identity :unique_huddl_user, [:huddl_id, :user_id]
  end
end
