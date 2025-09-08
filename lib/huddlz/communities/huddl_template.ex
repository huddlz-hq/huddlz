defmodule Huddlz.Communities.HuddlTemplate do
  @moduledoc """
  A huddl template contains core information for recurring huddlz
  """

  use Ash.Resource,
    otp_app: :huddlz,
    domain: Huddlz.Communities,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "huddl_templates"
    repo Huddlz.Repo
  end

  actions do
    read :read do
      primary? true
    end

    create :create do
      primary? true

      accept [
        :repeat_until,
        :frequency
      ]
    end

    update :update do
      primary? true

      accept [
        :repeat_until,
        :frequency
      ]

      require_atomic? false
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :repeat_until, :utc_datetime do
      allow_nil? false
    end

    attribute :frequency, :atom do
      allow_nil? false
      constraints one_of: [:weekly, :monthly]
      default :weekly
    end
  end
end
