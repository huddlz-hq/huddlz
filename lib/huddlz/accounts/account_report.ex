defmodule Huddlz.Accounts.AccountReport do
  @moduledoc """
  A confirmed member's request for administrators to review an account
  they can already see: spam or advertising, or another concern, with
  optional details.

  A report never suspends anyone by itself. Administrators read the queue,
  look at the account within their ordinary access, suspend when
  warranted, and mark the report handled. The reporter gets one thanks
  and nothing else. Report details and reporter identities are available
  only to trusted huddlz staff through account administration; no report
  notification is sent to the reported person.
  Reports expire two years after they were sent, whatever became of the
  account.
  """

  use Ash.Resource,
    otp_app: :huddlz,
    domain: Huddlz.Accounts,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshGraphql.Resource, AshJsonApi.Resource]

  alias Huddlz.Accounts.User

  graphql do
    type :account_report

    mutations do
      create :report_account, :report
    end
  end

  json_api do
    type "account_report"

    routes do
      base "/account_reports"
      post :report
    end
  end

  postgres do
    table "account_reports"
    repo Huddlz.Repo

    references do
      reference :reported_user, on_delete: :delete
      reference :reporter, on_delete: :delete
      reference :handled_by, on_delete: :nilify
    end

    identity_wheres_to_sql open_report: "handled_at IS NULL"
  end

  actions do
    defaults [:read]

    create :report do
      description """
      Report an account to the administrators. Sending the same report
      again while one is still open changes nothing; once the earlier
      report has expired, a new one takes its place.
      """

      accept [:reported_user_id, :details, :source_type, :source_id]

      argument :reason, Huddlz.Accounts.AccountReport.Reason

      validate present(:reason) do
        message "Say what's wrong: spam or advertising, or other."
      end

      change set_attribute(:reason, arg(:reason))
      # Let the confirmation policy refuse anonymous callers rather than
      # failing to relate them; stored reports still require a reporter.
      change relate_actor(:reporter, allow_nil?: true)
      change Huddlz.Accounts.AccountReport.Changes.SetExpiry

      upsert? true
      upsert_identity :open_report
      upsert_condition expr(expires_at <= now())
      upsert_fields [:reason, :details, :source_type, :source_id, :expires_at, :inserted_at]
      return_skipped_upsert? true
    end

    read :queue do
      description "The administrators' queue: open reports, or handled ones, newest first, expired ones gone"

      argument :handled, :boolean do
        description "List handled reports instead of open ones"
        default false
      end

      argument :reported_user_id, :uuid

      filter expr(expires_at > now() and is_nil(handled_at) == not (^arg(:handled)))
      filter expr(is_nil(^arg(:reported_user_id)) or reported_user_id == ^arg(:reported_user_id))
      prepare build(sort: [inserted_at: :desc])
    end

    action :count_queue, :integer do
      description "Count unexpired reports using the same rules as the queue"
      argument :handled, :boolean, default: false

      run fn input, context ->
        __MODULE__
        |> Ash.Query.for_read(:queue, input.arguments, actor: context.actor)
        |> Ash.count()
      end
    end

    update :reopen do
      description "Reopen an unexpired report that was handled by mistake"
      require_atomic? false
      accept []

      validate present(:handled_at)
      validate compare(:expires_at, greater_than: &DateTime.utc_now/0)
      change set_attribute(:handled_at, nil)
      change set_attribute(:handled_by_id, nil)
    end

    update :mark_handled do
      description "Close one report once an administrator has looked at it"
      require_atomic? false
      accept []

      validate absent(:handled_at) do
        message "is already handled"
      end

      change set_attribute(:handled_at, &DateTime.utc_now/0)
      change relate_actor(:handled_by)
    end
  end

  policies do
    policy action(:report) do
      description "Confirmed members report accounts they can already see, never themselves"
      forbid_unless Huddlz.Accounts.Checks.ConfirmedActor
      authorize_if Huddlz.Accounts.AccountReport.Checks.ReporterCanSeeAccount
    end

    policy action([:read, :queue, :count_queue, :mark_handled, :reopen]) do
      description "Only administrators see or handle reports"
      authorize_if actor_attribute_equals(:role, :admin)
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :reason, Huddlz.Accounts.AccountReport.Reason do
      description "What is wrong: spam or advertising, or something else"
      public? true
    end

    attribute :details, :string do
      description "The reporter's own words, if any"
      constraints max_length: 1000, trim?: true
      public? true
    end

    attribute :source_type, :atom do
      description "The kind of page the report was sent from"
      constraints one_of: [:huddl, :group]
      public? true
    end

    attribute :source_id, :uuid do
      description "The huddl or group the report was sent from"
      public? true
    end

    attribute :handled_at, :utc_datetime_usec do
      description "When an administrator marked the report handled"
      public? true
    end

    attribute :expires_at, :utc_datetime_usec do
      description "Two years after the report was sent; it is not shown after this"
      allow_nil? false
      public? true
    end

    create_timestamp :inserted_at do
      public? true
    end

    update_timestamp :updated_at
  end

  # The people on a report stay off the API shape: a reporter receives their
  # own report back and must learn nothing about the account through it.
  relationships do
    belongs_to :reported_user, User do
      description "The account being reported"
      allow_nil? false
      attribute_public? true
    end

    belongs_to :reporter, User do
      description "Who sent the report; administrators only"
      allow_nil? false
    end

    belongs_to :handled_by, User do
      description "The administrator who marked the report handled"
    end
  end

  calculations do
    calculate :source, :map, Huddlz.Accounts.AccountReport.Calculations.Source

    calculate :handled, :boolean, expr(not is_nil(handled_at)) do
      public? true
    end
  end

  identities do
    identity :open_report, [:reporter_id, :reported_user_id] do
      where expr(is_nil(handled_at))
    end
  end
end
