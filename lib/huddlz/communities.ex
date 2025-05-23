defmodule Huddlz.Communities do
  @moduledoc """
  The Communities domain manages groups, huddlz, and group memberships.
  """

  use Ash.Domain,
    otp_app: :huddlz

  resources do
    resource Huddlz.Communities.Huddl do
      define :get_upcoming, action: :upcoming
      define :search_huddlz, action: :search, args: [:query]
      define :get_by_status, action: :by_status, args: [:status]
    end

    resource Huddlz.Communities.Group do
      define :create_group,
        action: :create_group,
        args: [:name, :description, :location, :image_url, :is_public, :owner_id]

      define :search_groups, action: :search, args: [:query]
      define :get_by_owner, action: :get_by_owner, args: [:owner_id]

      define :update_details,
        action: :update_details,
        args: [:name, :description, :location, :image_url, :is_public]
    end

    resource Huddlz.Communities.GroupMember do
      define :add_member, action: :add_member, args: [:group_id, :user_id, :role]
      define :remove_member, action: :remove_member, args: [:group_id, :user_id]
      define :get_by_group, action: :get_by_group, args: [:group_id]
      define :get_by_user, action: :get_by_user, args: [:user_id]
    end
  end
end
