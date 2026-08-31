defmodule Huddlz.Communities do
  @moduledoc """
  The Communities domain manages groups, huddlz, and group memberships.
  """

  use Ash.Domain,
    otp_app: :huddlz,
    extensions: [AshJsonApi.Domain, AshGraphql.Domain]

  resources do
    resource Huddlz.Communities.Huddl do
      define :get_huddl, action: :read, get_by: [:id]

      define :search_huddlz,
        action: :search,
        args: [
          :query,
          {:optional, :date_filter},
          {:optional, :event_type},
          {:optional, :search_latitude},
          {:optional, :search_longitude},
          {:optional, :distance_miles},
          {:optional, :relationship},
          {:optional, :sort}
        ],
        get?: false

      define :get_group_huddlz, action: :by_group, args: [:group_id]
      define :get_past_group_huddlz, action: :past_by_group, args: [:group_id]
      define :list_upcoming_huddlz, action: :upcoming, get?: false

      define :list_calendar_huddlz,
        action: :calendar,
        args: [:range_start, :range_end],
        get?: false

      define :huddlz_for_organizer,
        action: :huddlz_for_organizer,
        args: [{:optional, :state}],
        get?: false

      define :update_huddl, action: :update
      define :rsvp_huddl, action: :rsvp
      define :cancel_rsvp_huddl, action: :cancel_rsvp
      define :join_waitlist_huddl, action: :join_waitlist
      define :publish_huddl, action: :publish
      define :cancel_huddl, action: :cancel, args: [{:optional, :cancellation_reason}]
      define :complete_huddl, action: :complete
      define :destroy_huddl, action: :destroy
    end

    resource Huddlz.Communities.Group do
      define :create_group,
        action: :create_group,
        args: [:name, :description, :location, :is_public]

      define :search_groups, action: :search, args: [{:optional, :search}]
      define :get_by_owner, action: :get_by_owner
      define :get_organizable_groups, action: :get_organizable
      define :get_joined_groups, action: :get_joined
      define :my_groups, action: :my_groups, args: [{:optional, :relationship}]
      define :get_by_slug, action: :get_by_slug, args: [:slug]
      define :get_group_for_organize, action: :get_for_organize, args: [:slug], get?: true

      define :update_details,
        action: :update_details,
        args: [:name, :description, :location, :is_public, :slug]

      define :transfer_group_ownership,
        action: :transfer_ownership,
        args: [:new_owner_id]

      define :destroy_group, action: :destroy
    end

    resource Huddlz.Communities.GroupImage do
      define :create_group_image, action: :create
      define :create_pending_group_image, action: :create_pending
      define :assign_group_image_to_group, action: :assign_to_group, args: [:group_id]
      define :get_current_group_image, action: :get_current_for_group, args: [:group_id]
      define :list_group_images, action: :list_for_group, args: [:group_id]
      define :get_orphaned_pending_images, action: :orphaned_pending
      define :delete_group_image, action: :destroy
      define :soft_delete_group_image, action: :soft_delete
    end

    resource Huddlz.Communities.HuddlImage do
      define :create_huddl_image, action: :create
      define :create_pending_huddl_image, action: :create_pending, args: [:group_id]
      define :assign_huddl_image_to_huddl, action: :assign_to_huddl, args: [:huddl_id]
      define :get_huddl_image_by_id, action: :read, get_by: [:id]
      define :get_current_huddl_image, action: :get_current_for_huddl, args: [:huddl_id]
      define :list_huddl_images, action: :list_for_huddl, args: [:huddl_id]
      define :get_orphaned_pending_huddl_images, action: :orphaned_pending
      define :delete_huddl_image, action: :destroy
      define :soft_delete_huddl_image, action: :soft_delete
    end

    resource Huddlz.Communities.GroupMember do
      define :add_member, action: :add_member, args: [:group_id, :user_id, :role]
      define :get_group_member, action: :read, get_by: [:group_id, :user_id]

      define :accept_invitation_membership,
        action: :accept_invitation,
        args: [:group_id, :user_id, :role]

      define :set_member_role_from_invitation, action: :set_role, args: [:role]
      define :remove_member, action: :remove_member, args: [:group_id, :user_id]
      define :change_member_role, action: :change_role, args: [:role]
      define :get_by_group, action: :get_by_group, args: [:group_id]
      define :get_by_user, action: :get_by_user
      define :get_membership_in_group, action: :get_in_group, args: [:group_id], get?: true
    end

    resource Huddlz.Communities.GroupInvitation do
      define :invite_to_group,
        action: :invite,
        args: [:group_id, :invitee_id, {:optional, :role}]

      define :list_my_group_invitations, action: :mine
      define :get_group_invitation, action: :read, get_by: [:id]
      define :get_my_group_invitation, action: :get_mine, args: [:id], get?: true
      define :list_group_invitations, action: :for_group, args: [:group_id]
      define :accept_group_invitation, action: :accept
      define :decline_group_invitation, action: :decline
      define :revoke_group_invitation, action: :revoke
      define :expire_group_invitation, action: :expire
      define :list_pending_group_invitations_for_user, action: :pending_for_user
      define :count_pending_group_invitations_for_user, action: :count_pending_for_user
    end

    resource Huddlz.Communities.HuddlAttendee do
      define :check_user_rsvp, action: :check_rsvp, args: [:huddl_id]
      define :list_huddl_attendees, action: :by_huddl, args: [:huddl_id], get?: false
      define :list_huddl_waitlist, action: :waitlist_for_huddl, args: [:huddl_id], get?: false

      define :list_huddl_notification_recipients,
        action: :notification_recipients,
        args: [:huddl_ids],
        get?: false
    end

    resource Huddlz.Communities.HuddlTemplate

    resource Huddlz.Communities.GroupLocation do
      define :create_group_location,
        action: :create,
        args: [:name, :address, :latitude, :longitude, :group_id]

      define :list_group_locations, action: :by_group, args: [:group_id]
      define :get_group_location, action: :read, get_by: [:id]
      define :update_group_location, action: :update
      define :destroy_group_location, action: :destroy
    end
  end

  @doc """
  Deletes a saved location and distinguishes an already-completed deletion
  from a failed deletion.

  Concurrent callers can safely treat `{:ok, :already_deleted}` as success.
  """
  def delete_group_location(location, opts \\ []) do
    case destroy_group_location(location, opts) do
      :ok ->
        :ok

      {:error, error} ->
        deletion_result_after_error(location.id, error)
    end
  end

  defp deletion_result_after_error(location_id, original_error) do
    case get_group_location(location_id,
           authorize?: false,
           not_found_error?: false
         ) do
      {:ok, nil} -> {:ok, :already_deleted}
      {:ok, _location} -> {:error, original_error}
      {:error, _lookup_error} -> {:error, original_error}
    end
  end

  @doc """
  Loads the private invitation details after an invitation action has already
  authorized access to the invitation itself.
  """
  def load_group_invitation_details!(invitation) do
    Ash.load!(invitation, [:group, :invitee, :inviter], authorize?: false)
  end
end
