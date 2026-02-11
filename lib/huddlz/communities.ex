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
      define :get_upcoming, action: :upcoming

      define :search_huddlz,
        action: :search,
        args: [
          :query,
          {:optional, :date_filter},
          {:optional, :event_type},
          {:optional, :search_latitude},
          {:optional, :search_longitude},
          {:optional, :distance_miles}
        ],
        get?: false

      define :get_by_status, action: :by_status, args: [:status]
      define :get_group_huddlz, action: :by_group, args: [:group_id]
      define :get_past_group_huddlz, action: :past_by_group, args: [:group_id]
      define :rsvp_huddl, action: :rsvp, args: [:user_id]
      define :cancel_rsvp_huddl, action: :cancel_rsvp, args: [:user_id]
      define :destroy_huddl, action: :destroy
    end

    resource Huddlz.Communities.Group do
      define :create_group,
        action: :create_group,
        args: [:name, :description, :location, :is_public, :owner_id]

      define :search_groups, action: :search, args: [:query]
      define :get_by_owner, action: :get_by_owner, args: [:owner_id]
      define :get_by_slug, action: :get_by_slug, args: [:slug]

      define :update_details,
        action: :update_details,
        args: [:name, :description, :location, :is_public, :slug]
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
      define :get_current_huddl_image, action: :get_current_for_huddl, args: [:huddl_id]
      define :list_huddl_images, action: :list_for_huddl, args: [:huddl_id]
      define :get_orphaned_pending_huddl_images, action: :orphaned_pending
      define :delete_huddl_image, action: :destroy
      define :soft_delete_huddl_image, action: :soft_delete
    end

    resource Huddlz.Communities.GroupMember do
      define :add_member, action: :add_member, args: [:group_id, :user_id, :role]
      define :remove_member, action: :remove_member, args: [:group_id, :user_id]
      define :get_by_group, action: :get_by_group, args: [:group_id]
      define :get_by_user, action: :get_by_user, args: [:user_id]
    end

    resource Huddlz.Communities.HuddlAttendee do
      define :rsvp_to_huddl, action: :rsvp, args: [:huddl_id, :user_id]
      define :cancel_huddl_rsvp, action: :cancel_rsvp
      define :get_huddl_attendees, action: :by_huddl, args: [:huddl_id]
      define :get_user_rsvps, action: :by_user, args: [:user_id]
      define :check_user_rsvp, action: :check_rsvp, args: [:huddl_id, :user_id]
    end

    resource Huddlz.Communities.HuddlTemplate
  end
end
