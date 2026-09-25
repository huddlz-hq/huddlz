defmodule Huddlz.Admin.CopyMeasurement do
  @moduledoc """
  When complete copy measurement began, recorded once by deployment.
  Earlier copies remain countable, but their recording coverage and source
  timing are not assumed. Copy activity never changes this boundary.
  """
  use Ash.Resource,
    otp_app: :huddlz,
    domain: Huddlz.Admin,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "copy_measurement"
    repo Huddlz.Repo

    custom_statements do
      statement :begin_collection do
        up "INSERT INTO copy_measurement (id, started_at) VALUES (1, (CURRENT_TIMESTAMP AT TIME ZONE 'UTC'))"
        down "DELETE FROM copy_measurement WHERE id = 1"
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

    attribute :started_at, :utc_datetime_usec do
      allow_nil? false
    end
  end
end
