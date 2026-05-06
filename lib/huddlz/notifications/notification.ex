defmodule Huddlz.Notifications.Notification do
  @moduledoc """
  Persistent in-app notification record.

  Created from `Huddlz.Notifications.deliver/3` whenever a trigger fires
  for a user. Backs the Updates tab on `/me`. Email pref affects email
  delivery only — every triggered notification is recorded here so the
  in-app feed is canonical.
  """

  use Ash.Resource,
    otp_app: :huddlz,
    domain: Huddlz.Notifications,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "notifications"
    repo Huddlz.Repo

    references do
      reference :user, on_delete: :delete
    end

    custom_indexes do
      index [:user_id, :inserted_at]
      index [:user_id, :read_at]
    end
  end

  actions do
    defaults [:read]

    create :create do
      description "System-only: persist a triggered notification for a user."

      accept [:trigger, :payload, :title, :description, :source_url]

      argument :user_id, :uuid do
        allow_nil? false
      end

      change manage_relationship(:user_id, :user, type: :append)
    end

    read :for_user do
      description "List the actor's notifications, newest first."

      filter expr(user_id == ^actor(:id))
      prepare build(sort: [inserted_at: :desc])

      pagination keyset?: true,
                 offset?: true,
                 countable: true,
                 required?: false,
                 default_limit: 20
    end

    read :invites_for_user do
      description """
      Unread notifications that need a response from the actor — backs the
      Invites tab on /me. The "needs response" trigger set is intentionally
      narrow; revisit when new invitation flows ship.
      """

      filter expr(
               user_id == ^actor(:id) and is_nil(read_at) and
                 trigger in ["waitlist_promoted", "group_member_added"]
             )

      prepare build(sort: [inserted_at: :desc])

      pagination keyset?: true,
                 offset?: true,
                 countable: true,
                 required?: false,
                 default_limit: 20
    end

    update :mark_read do
      description "Mark a notification as read. No-op if already read."
      require_atomic? false

      change fn changeset, _ctx ->
        case Ash.Changeset.get_attribute(changeset, :read_at) do
          nil -> Ash.Changeset.change_attribute(changeset, :read_at, DateTime.utc_now())
          _ -> changeset
        end
      end
    end

    update :mark_unread do
      description "Clear the read marker on a notification."
      change set_attribute(:read_at, nil)
    end
  end

  policies do
    bypass actor_attribute_equals(:role, :admin) do
      authorize_if always()
    end

    # System-driven create from Huddlz.Notifications.deliver/3 runs with
    # authorize?: false. No user-facing path creates notifications.
    policy action(:create) do
      authorize_if always()
    end

    policy action(:for_user) do
      authorize_if actor_present()
    end

    policy action(:invites_for_user) do
      authorize_if actor_present()
    end

    policy action_type([:update]) do
      authorize_if relates_to_actor_via(:user)
    end

    policy action(:read) do
      description "Default read used internally; user-facing reads use :for_user"
      authorize_if always()
    end
  end

  attributes do
    uuid_primary_key :id

    create_timestamp :inserted_at

    attribute :trigger, :string do
      allow_nil? false
      public? true
      description "Trigger code (e.g., \"rsvp_confirmation\") from Huddlz.Notifications.Triggers."
    end

    attribute :payload, :map do
      allow_nil? false
      default %{}
      public? true
    end

    attribute :title, :string do
      allow_nil? false
      public? true
    end

    attribute :description, :string do
      allow_nil? true
      public? true
    end

    attribute :source_url, :string do
      allow_nil? true
      public? true
      description "Path within the app this notification points to, e.g. /groups/foo/huddlz/<id>."
    end

    attribute :read_at, :utc_datetime_usec do
      allow_nil? true
      public? true
      description "Set when the user marks the notification as read; nil = unread."
    end
  end

  relationships do
    belongs_to :user, Huddlz.Accounts.User do
      attribute_type :uuid
      allow_nil? false
      primary_key? false
    end
  end
end
