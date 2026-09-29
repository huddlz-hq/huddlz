defmodule Huddlz.Communities.HuddlTemplate do
  @moduledoc """
  A huddl template contains core information for recurring huddlz
  """

  use Ash.Resource,
    otp_app: :huddlz,
    domain: Huddlz.Communities,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshPaperTrail.Resource]

  postgres do
    table "huddl_templates"
    repo Huddlz.Repo

    references do
      reference :source_huddl, on_delete: :nilify
    end
  end

  paper_trail do
    change_tracking_mode :snapshot
    store_action_name? true
    reference_source? false
    sensitive_attributes :ignore
    ignore_attributes [:inserted_at, :updated_at]
    belongs_to_actor :actor, Huddlz.Accounts.User, domain: Huddlz.Accounts, on_delete: :nilify
    metadata :impersonation_id, :uuid
    metadata :impersonator_id, :uuid
    metadata :automatic?, :boolean
    version_extensions authorizers: [Ash.Policy.Authorizer]
    mixin {Huddlz.Audit.Version, :mixin, []}
  end

  actions do
    read :read do
      primary? true
    end

    read :due_for_maintenance do
      description """
      Internal, visibility-free listing of the series that are still
      generating (no end date, or one still ahead). Deliberately does not
      filter on the owning group's state: reaching the group means
      traversing `huddlz`, whose default read action applies
      FilterByVisibility, which would silently drop every private group's
      series when this runs with no actor. The archived-group guard instead
      lives in MaintainRecurringSeries, the single path through which
      occurrences are created. Invoke only with `authorize?: false`.
      """

      filter expr(is_nil(repeat_until) or repeat_until > now())
    end

    create :create do
      primary? true

      accept [
        :repeat_until,
        :interval,
        :unit,
        :starts_at_local,
        :ends_at_local,
        :time_zone,
        :source_huddl_id
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
        :time_zone,
        :source_huddl_id
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
    policy action(:due_for_maintenance) do
      forbid_if always()
    end

    # Templates are managed through huddl actions.
    policy action_type([:create, :update, :destroy]) do
      forbid_if always()
    end

    policy action_type(:read) do
      authorize_if expr(exists(huddlz, group.is_public == true and is_nil(group.archived_at)))
      authorize_if expr(exists(huddlz, exists(group.members, id == ^actor(:id))))
    end
  end

  validations do
    validate Huddlz.TimeZone.Validation
  end

  attributes do
    uuid_primary_key :id

    attribute :repeat_until, :utc_datetime do
      description """
      The last local date the series may occupy. `nil` means the series is
      boundless: it keeps generating until an organizer stops it.
      """

      allow_nil? true
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
      constraints min_length: 1, max_length: 100
    end
  end

  relationships do
    has_many :huddlz, Huddlz.Communities.Huddl do
      destination_attribute :huddl_template_id
    end

    # The huddl whose details every generated occurrence copies: the creating
    # huddl at first, then whichever occurrence an "edit all" was made from.
    # Nullable so the template can still be created before the huddl's insert,
    # and nilified rather than cascading if that huddl is ever hard-deleted.
    belongs_to :source_huddl, Huddlz.Communities.Huddl do
      attribute_type :uuid
      allow_nil? true
    end
  end

  @doc """
  Returns the form-facing cadence represented by an explicit interval and unit.
  """
  def cadence(%__MODULE__{interval: 1, unit: :week}), do: :weekly
  def cadence(%__MODULE__{interval: 2, unit: :week}), do: :every_two_weeks
  def cadence(%__MODULE__{interval: 1, unit: :month}), do: :monthly

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
