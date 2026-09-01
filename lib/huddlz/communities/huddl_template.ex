defmodule Huddlz.Communities.HuddlTemplate do
  @moduledoc """
  A huddl template contains core information for recurring huddlz
  """

  use Ash.Resource,
    otp_app: :huddlz,
    domain: Huddlz.Communities,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

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
        :interval,
        :unit,
        :starts_at_local,
        :ends_at_local,
        :time_zone
      ]

      argument :frequency, :atom do
        allow_nil? true
        constraints one_of: [:weekly, :every_two_weeks, :monthly]
      end

      change Huddlz.Communities.HuddlTemplate.Changes.SetRecurrenceFromFrequency
    end

    update :update do
      primary? true

      accept [
        :repeat_until,
        :interval,
        :unit,
        :starts_at_local,
        :ends_at_local,
        :time_zone
      ]

      argument :frequency, :atom do
        allow_nil? true
        constraints one_of: [:weekly, :every_two_weeks, :monthly]
      end

      change Huddlz.Communities.HuddlTemplate.Changes.SetRecurrenceFromFrequency
      require_atomic? false
    end
  end

  policies do
    bypass actor_attribute_equals(:role, :admin) do
      authorize_if always()
    end

    # Templates are managed internally; require admin for direct access
    policy action_type([:create, :update, :destroy]) do
      forbid_if always()
    end

    policy action_type(:read) do
      authorize_if always()
    end
  end

  validations do
    validate Huddlz.TimeZone.Validation
  end

  attributes do
    uuid_primary_key :id

    attribute :repeat_until, :utc_datetime do
      allow_nil? false
    end

    attribute :interval, :integer do
      allow_nil? false
      constraints min: 1
      default 1
    end

    attribute :unit, :atom do
      allow_nil? false
      constraints one_of: [:week, :month]
      default :week
    end

    attribute :starts_at_local, :naive_datetime do
      allow_nil? false
    end

    attribute :ends_at_local, :naive_datetime do
      allow_nil? false
    end

    attribute :time_zone, :string do
      allow_nil? false
    end
  end

  @doc """
  Returns the form-facing cadence represented by an explicit interval and unit.
  """
  def cadence(%__MODULE__{interval: 1, unit: :week}), do: :weekly
  def cadence(%__MODULE__{interval: 2, unit: :week}), do: :every_two_weeks
  def cadence(%__MODULE__{interval: 1, unit: :month}), do: :monthly

  @doc """
  Captures the authoritative local schedule used to generate a huddl series.
  """
  def wall_clock_schedule(%{starts_at: starts_at, ends_at: ends_at, time_zone: time_zone}) do
    %{
      starts_at_local: local_naive(starts_at, time_zone),
      ends_at_local: local_naive(ends_at, time_zone),
      time_zone: time_zone
    }
  end

  defp local_naive(datetime, time_zone) do
    datetime
    |> DateTime.shift_zone!(time_zone)
    |> DateTime.to_naive()
  end
end
