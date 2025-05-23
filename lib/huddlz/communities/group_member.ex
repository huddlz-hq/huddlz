defmodule Huddlz.Communities.GroupMember do
  @moduledoc """
  Represents membership of users in groups with different roles (owner, organizer, member).
  """

  use Ash.Resource,
    otp_app: :huddlz,
    domain: Huddlz.Communities,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  alias Huddlz.Communities.GroupMember.Checks.GroupOrganizer
  alias Huddlz.Communities.GroupMember.Checks.GroupOwner
  alias Huddlz.Communities.GroupMember.Checks.GroupVerifiedMember

  postgres do
    table "group_members"
    repo Huddlz.Repo
  end

  actions do
    defaults [:create, :read, :destroy]

    create :add_member do
      description "Add a user to a group"

      argument :group_id, :uuid do
        allow_nil? false
      end

      argument :user_id, :uuid do
        allow_nil? false
      end

      argument :role, :string do
        allow_nil? false
        default "member"
      end

      change manage_relationship(:group_id, :group, type: :append)
      change manage_relationship(:user_id, :user, type: :append)
      change set_attribute(:role, arg(:role))

      validate Huddlz.Communities.GroupMember.Validations.VerifiedForElevatedRoles
    end

    destroy :remove_member do
      description "Remove a user from a group"

      argument :group_id, :uuid do
        allow_nil? false
      end

      argument :user_id, :uuid do
        allow_nil? false
      end

      filter expr(group_id == ^arg(:group_id))
      filter expr(user_id == ^arg(:user_id))
    end

    read :get_by_group do
      description "Get all members of a group"

      argument :group_id, :uuid do
        allow_nil? false
      end

      filter expr(group_id == ^arg(:group_id))
    end

    read :get_by_user do
      description "Get all groups a user is a member of"

      argument :user_id, :uuid do
        allow_nil? false
      end

      filter expr(user_id == ^arg(:user_id))
    end
  end

  policies do
    # Admin bypass - admins can do everything
    bypass actor_attribute_equals(:role, :admin) do
      authorize_if always()
    end

    # Only group owners can add members (custom check for create)
    policy action(:add_member) do
      # Only the owner or an organizer (must be verified) can add members
      authorize_if GroupOwner
      authorize_if GroupOrganizer
    end

    # Group owners can remove members
    policy action(:remove_member) do
      authorize_if GroupOwner
    end

    policy action(:get_by_group) do
      authorize_if GroupOwner
      authorize_if GroupOrganizer
      authorize_if GroupVerifiedMember
      authorize_if Huddlz.Communities.GroupMember.Checks.VerifiedNonMemberPublicGroup

      # Explicitly forbid everyone else
      forbid_if always()
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :role, :atom do
      allow_nil? false
      default :member
      constraints one_of: [:owner, :organizer, :member]
    end

    create_timestamp :created_at
  end

  relationships do
    belongs_to :group, Huddlz.Communities.Group do
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
    identity :unique_group_user, [:group_id, :user_id]
  end
end
