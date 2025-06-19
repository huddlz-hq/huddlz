defmodule Huddlz.Communities do
  @moduledoc """
  The Communities domain manages groups, huddlz, and group memberships.
  """

  use Ash.Domain,
    otp_app: :huddlz

  resources do
    resource Huddlz.Communities.Huddl do
      define :get_upcoming, action: :upcoming

      define :search_huddlz,
        action: :search,
        args: [:query, {:optional, :date_filter}, {:optional, :event_type}]

      define :get_by_status, action: :by_status, args: [:status]
      define :get_group_huddlz, action: :by_group, args: [:group_id]
      define :get_past_group_huddlz, action: :past_by_group, args: [:group_id]
    end

    resource Huddlz.Communities.Group do
      define :create_group,
        action: :create_group,
        args: [:name, :description, :location, :image_url, :is_public, :owner_id]

      define :search_groups, action: :search, args: [:query]
      define :get_by_owner, action: :get_by_owner, args: [:owner_id]
      define :get_by_slug, action: :get_by_slug, args: [:slug]

      define :update_details,
        action: :update_details,
        args: [:name, :description, :location, :image_url, :is_public, :slug]
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
  end
end
