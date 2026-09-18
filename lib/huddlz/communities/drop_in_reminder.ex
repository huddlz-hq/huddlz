defmodule Huddlz.Communities.DropInReminder do
  @moduledoc """
  What huddlz remembers about reminding one person that they can join one
  group. A drop-in (someone with an RSVP or waitlist spot at a group's huddl
  who has not joined the group) is reminded once per group; this row is how
  "once" is kept:

    * `emailed_at` — the join suggestion email went out.
    * `dismissed_at` — they answered "Not now".
    * `closed_at` — they left the group or were removed from it, which says
      more than not joining ever could.

  A row with `dismissed_at` or `closed_at` ends every reminder for that
  group. It carries no reason and no actor, and it is kept for as long as the
  account and the group exist: it is a standing "don't remind", not audit
  history, so the two-year window does not apply (ADR-0011).
  """

  use Ash.Resource,
    otp_app: :huddlz,
    domain: Huddlz.Communities,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshJsonApi.Resource, AshGraphql.Resource]

  graphql do
    type :drop_in_reminder

    mutations do
      create :dismiss_join_suggestion, :dismiss
    end
  end

  json_api do
    type "drop_in_reminder"

    routes do
      base "/drop_in_reminders"

      post :dismiss, route: "/dismiss"
    end
  end

  postgres do
    table "drop_in_reminders"
    repo Huddlz.Repo

    references do
      reference :group, on_delete: :delete
      reference :user, on_delete: :delete
    end

    custom_indexes do
      index [:user_id]
    end
  end

  actions do
    defaults [:read]

    create :dismiss do
      description "Not now: the actor does not want to be reminded about joining this group."

      argument :group_id, :uuid do
        allow_nil? false
      end

      upsert? true
      upsert_identity :unique_group_user
      upsert_fields [:dismissed_at, :updated_at]

      change manage_relationship(:group_id, :group, type: :append)
      change relate_actor(:user)
      change set_attribute(:dismissed_at, &DateTime.utc_now/0)
    end

    create :close do
      description """
      Internal: the person left the group or was removed from it. Always
      forbidden by policy; callers pass `authorize?: false`.
      """

      accept [:group_id, :user_id]

      upsert? true
      upsert_identity :unique_group_user
      upsert_fields [:closed_at, :updated_at]

      change set_attribute(:closed_at, &DateTime.utc_now/0)
    end

    read :for_group do
      description "The actor's own reminder row for one group, or nil."
      get? true

      argument :group_id, :uuid do
        allow_nil? false
      end

      filter expr(group_id == ^arg(:group_id) and user_id == ^actor(:id))
      prepare build(load: [:suppressed?])
    end
  end

  policies do
    policy [action_type(:create), actor_present()] do
      authorize_if Huddlz.Accounts.Checks.ConfirmedActor
    end

    policy action(:dismiss) do
      authorize_if actor_present()
    end

    # Internal-only — must be called with `authorize?: false`.
    policy action(:close) do
      forbid_if always()
    end

    policy action_type(:read) do
      description "Only your own reminder rows"
      authorize_if relates_to_actor_via(:user)
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :emailed_at, :utc_datetime_usec, public?: true
    attribute :dismissed_at, :utc_datetime_usec, public?: true
    attribute :closed_at, :utc_datetime_usec, public?: true

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :group, Huddlz.Communities.Group do
      read_action :read_with_archived
      attribute_type :uuid
      allow_nil? false
      public? true
    end

    belongs_to :user, Huddlz.Accounts.User do
      read_action :read_for_others
      attribute_type :uuid
      allow_nil? false
    end
  end

  calculations do
    calculate :suppressed?,
              :boolean,
              expr(not is_nil(dismissed_at) or not is_nil(closed_at)) do
      description "Whether this person has permanently ended join suggestions for the group."
    end
  end

  identities do
    identity :unique_group_user, [:group_id, :user_id]
  end
end
