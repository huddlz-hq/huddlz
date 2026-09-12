defmodule Huddlz.Accounts.ActiveDay do
  @moduledoc """
  One row per person per UTC calendar day on which they used huddlz while
  signed in: a page request, a LiveView opened by navigation, or an
  authenticated API call. Nothing else is kept, not the page and not the
  time of day. The rows are what the admin overview's active people figure
  counts, and what future retention charts will count, so they stay as
  long as the account does and go with it.

  `Huddlz.Accounts.ActiveDays.mark/2` writes them for the browser and API
  plugs and the LiveView mount hook. Recording upserts on the person and
  the day, so repeated use on a day and concurrent requests never make a
  second row. Only administrators read them, and only through the admin
  overview's figures.
  """

  use Ash.Resource,
    otp_app: :huddlz,
    domain: Huddlz.Accounts,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "active_days"
    repo Huddlz.Repo

    references do
      reference :user, on_delete: :delete
    end

    custom_indexes do
      index [:day]
    end
  end

  actions do
    defaults [:read]

    create :record do
      description """
      Mark the actor as having used huddlz on a UTC day. A second mark on
      the same day changes nothing.
      """

      accept [:day]
      upsert? true
      upsert_identity :one_per_day

      change relate_actor(:user)
    end
  end

  policies do
    policy action(:record) do
      description "Anyone signed in is recorded as themselves"
      authorize_if actor_present()
    end

    policy action_type(:read) do
      description "Only administrators count active people"
      authorize_if actor_attribute_equals(:role, :admin)
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :day, :date do
      allow_nil? false
      public? true
    end
  end

  relationships do
    belongs_to :user, Huddlz.Accounts.User do
      allow_nil? false
    end
  end

  identities do
    identity :one_per_day, [:user_id, :day]
  end
end
