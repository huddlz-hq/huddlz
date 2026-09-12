defmodule Huddlz.Accounts.UsageMeasurement do
  @moduledoc """
  The UTC date collection began, recorded by the deployment migration.
  Independent of accounts and usage, so measured zero days and account
  deletion never change coverage. The first date is only partially measured.
  """
  use Ash.Resource,
    otp_app: :huddlz,
    domain: Huddlz.Accounts,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "usage_measurement"
    repo Huddlz.Repo

    custom_statements do
      statement :begin_collection do
        up "INSERT INTO usage_measurement (id, started_on) VALUES (1, (CURRENT_TIMESTAMP AT TIME ZONE 'UTC')::date)"
        down "DELETE FROM usage_measurement WHERE id = 1"
      end
    end
  end

  actions do
    defaults [:read]
  end

  policies do
    policy action_type(:read) do
      authorize_if actor_attribute_equals(:role, :admin)
    end
  end

  attributes do
    attribute :id, :integer do
      primary_key? true
      allow_nil? false
      default 1
      constraints min: 1, max: 1
    end

    attribute :started_on, :date do
      allow_nil? false
    end
  end
end
